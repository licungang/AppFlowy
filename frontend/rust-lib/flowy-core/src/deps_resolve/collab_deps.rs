use std::sync::Arc;

use appflowy_integrate::{
  calculate_snapshot_diff, try_encode_snapshot, CollabSnapshot, MutexCollab, PersistenceError,
  Snapshot, SnapshotDB,
};
use diesel::SqliteConnection;

use flowy_error::FlowyError;
use flowy_sqlite::{
  insert_or_ignore_into,
  prelude::*,
  schema::{collab_snapshot, collab_snapshot::dsl},
};
use flowy_user::services::UserSession;
use lib_infra::util::timestamp;

pub struct SnapshotDBImpl(pub Arc<UserSession>);

impl SnapshotDB for SnapshotDBImpl {
  fn get_snapshots(&self, _uid: i64, object_id: &str) -> Vec<CollabSnapshot> {
    match self.0.db_pool() {
      Ok(pool) => match pool.get() {
        Ok(conn) => {
          let rows = CollabSnapshotTableSql::get_all_snapshots(object_id, &conn).unwrap();
          rows.into_iter().map(|row| row.into()).collect()
        },
        Err(_) => vec![],
      },
      Err(_) => vec![],
    }
  }

  fn create_snapshot(
    &self,
    uid: i64,
    object_id: &str,
    snapshot: Snapshot,
    collab: Arc<MutexCollab>,
  ) -> Result<(), PersistenceError> {
    let object_id = object_id.to_string();
    let weak_pool = Arc::downgrade(
      &self
        .0
        .db_pool()
        .map_err(|e| PersistenceError::Internal(Box::new(e)))?,
    );

    let _ = tokio::task::spawn_blocking(move || {
      if let Some(pool) = weak_pool.upgrade() {
        let conn = pool.get()?;
        let result = try_encode_snapshot(&collab.lock().transact(), snapshot);
        match result.and_then(|new_snapshot_data| {
          let desc = match CollabSnapshotTableSql::get_latest_snapshot(&object_id, &conn) {
            None => Ok("".to_string()),
            Some(old_snapshot) => {
              calculate_snapshot_diff(uid, &object_id, &old_snapshot.data, &new_snapshot_data)
            },
          }
          .map_err(|e| PersistenceError::InvalidData(format!("{:?}", e)))?;

          CollabSnapshotTableSql::create(
            CollabSnapshotRow {
              id: uuid::Uuid::new_v4().to_string(),
              object_id: object_id.clone(),
              desc,
              timestamp: timestamp(),
              data: new_snapshot_data,
            },
            &conn,
          )
          .map_err(|e| PersistenceError::Internal(Box::new(e)))
        }) {
          Ok(_) => {},
          Err(e) => tracing::error!("create snapshot error: {:?}", e),
        }
      }

      Ok::<(), FlowyError>(())
    });
    Ok(())
  }
}

#[derive(PartialEq, Clone, Debug, Queryable, Identifiable, Insertable, Associations)]
#[table_name = "collab_snapshot"]
struct CollabSnapshotRow {
  id: String,
  object_id: String,
  desc: String,
  timestamp: i64,
  data: Vec<u8>,
}

impl From<CollabSnapshotRow> for CollabSnapshot {
  fn from(table: CollabSnapshotRow) -> Self {
    Self {
      data: table.data,
      created_at: table.timestamp,
    }
  }
}

struct CollabSnapshotTableSql;
impl CollabSnapshotTableSql {
  fn create(row: CollabSnapshotRow, conn: &SqliteConnection) -> Result<(), FlowyError> {
    // Batch insert: https://diesel.rs/guides/all-about-inserts.html
    let values = (
      dsl::id.eq(row.id),
      dsl::object_id.eq(row.object_id),
      dsl::desc.eq(row.desc),
      dsl::data.eq(row.data),
      dsl::timestamp.eq(row.timestamp),
    );
    let _ = insert_or_ignore_into(dsl::collab_snapshot)
      .values(values)
      .execute(conn)?;
    Ok(())
  }

  fn get_all_snapshots(
    object_id: &str,
    conn: &SqliteConnection,
  ) -> Result<Vec<CollabSnapshotRow>, FlowyError> {
    let sql = dsl::collab_snapshot
      .filter(dsl::object_id.eq(object_id))
      .into_boxed();

    let rows = sql
      .order(dsl::timestamp.asc())
      .load::<CollabSnapshotRow>(conn)?;

    Ok(rows)
  }

  fn get_latest_snapshot(object_id: &str, conn: &SqliteConnection) -> Option<CollabSnapshotRow> {
    let sql = dsl::collab_snapshot
      .filter(dsl::object_id.eq(object_id))
      .into_boxed();

    sql
      .order(dsl::timestamp.desc())
      .first::<CollabSnapshotRow>(conn)
      .ok()
  }

  #[allow(dead_code)]
  fn delete(
    object_id: &str,
    snapshot_ids: Option<Vec<String>>,
    conn: &SqliteConnection,
  ) -> Result<(), FlowyError> {
    let mut sql = diesel::delete(dsl::collab_snapshot).into_boxed();
    sql = sql.filter(dsl::object_id.eq(object_id));

    if let Some(snapshot_ids) = snapshot_ids {
      tracing::trace!(
        "[{}] Delete snapshot: {}:{:?}",
        std::any::type_name::<Self>(),
        object_id,
        snapshot_ids
      );
      sql = sql.filter(dsl::id.eq_any(snapshot_ids));
    }

    let affected_row = sql.execute(conn)?;
    tracing::trace!(
      "[{}] Delete {} rows",
      std::any::type_name::<Self>(),
      affected_row
    );
    Ok(())
  }
}
