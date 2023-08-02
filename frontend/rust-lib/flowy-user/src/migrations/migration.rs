use crate::services::session_serde::Session;
use appflowy_integrate::RocksCollabDB;
use chrono::NaiveDateTime;
use diesel::{RunQueryDsl, SqliteConnection};
use flowy_error::FlowyResult;
use flowy_sqlite::schema::user_data_migration_records;
use flowy_sqlite::ConnectionPool;
use std::sync::Arc;

pub struct UserLocalDataMigration {
  session: Session,
  collab_db: Arc<RocksCollabDB>,
  sqlite_pool: Arc<ConnectionPool>,
}

impl UserLocalDataMigration {
  pub fn new(
    session: Session,
    collab_db: Arc<RocksCollabDB>,
    sqlite_pool: Arc<ConnectionPool>,
  ) -> Self {
    Self {
      session,
      collab_db,
      sqlite_pool,
    }
  }

  pub fn run(self, migrations: Vec<Box<dyn UserDataMigration>>) -> FlowyResult<Vec<String>> {
    let mut applied_migrations = vec![];
    let conn = self.sqlite_pool.get()?;
    let record = get_all_records(&*conn)?;
    for migration in migrations {
      if record
        .iter()
        .find(|record| record.migration_name == migration.name())
        .is_none()
      {
        migration.run(&self.session, &self.collab_db)?;
        applied_migrations.push(migration.name().to_string());
        save_record(&*conn, migration.name());
      }
    }
    Ok(applied_migrations)
  }
}

pub trait UserDataMigration {
  /// Migration with the same name will be skipped
  fn name(&self) -> &str;
  fn run(&self, user: &Session, collab_db: &Arc<RocksCollabDB>) -> FlowyResult<()>;
}

fn save_record(conn: &SqliteConnection, migration_name: &str) {
  let new_record = NewUserDataMigrationRecord {
    migration_name: migration_name.to_string(),
  };
  diesel::insert_into(user_data_migration_records::table)
    .values(&new_record)
    .execute(conn)
    .expect("Error inserting new migration record");
}

fn get_all_records(conn: &SqliteConnection) -> FlowyResult<Vec<UserDataMigrationRecord>> {
  Ok(
    user_data_migration_records::table
      .load::<UserDataMigrationRecord>(conn)
      .unwrap_or_default(),
  )
}

#[derive(Clone, Default, Queryable, Identifiable)]
#[table_name = "user_data_migration_records"]
pub struct UserDataMigrationRecord {
  pub id: i32,
  pub migration_name: String,
  pub executed_at: NaiveDateTime,
}

#[derive(Insertable)]
#[table_name = "user_data_migration_records"]
pub struct NewUserDataMigrationRecord {
  pub migration_name: String,
}
