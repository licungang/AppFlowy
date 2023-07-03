use std::{collections::HashMap, sync::Arc};

use appflowy_integrate::collab_builder::AppFlowyCollabBuilder;
use collab_document::blocks::DocumentData;
use collab_document::document::Document;
use collab_document::YrsDocAction;
use parking_lot::RwLock;

use flowy_error::{internal_error, FlowyError, FlowyResult};

use crate::deps::{DocumentCloudService, DocumentUser};
use crate::entities::DocumentSnapshotPB;
use crate::{document::MutexDocument, document_data::default_document_data};

pub struct DocumentManager {
  user: Arc<dyn DocumentUser>,
  collab_builder: Arc<AppFlowyCollabBuilder>,
  documents: Arc<RwLock<HashMap<String, Arc<MutexDocument>>>>,
  #[allow(dead_code)]
  cloud_service: Arc<dyn DocumentCloudService>,
}

impl DocumentManager {
  pub fn new(
    user: Arc<dyn DocumentUser>,
    collab_builder: Arc<AppFlowyCollabBuilder>,
    cloud_service: Arc<dyn DocumentCloudService>,
  ) -> Self {
    Self {
      user,
      collab_builder,
      documents: Default::default(),
      cloud_service,
    }
  }

  /// Create a new document.
  ///
  /// if the document already exists, return the existing document.
  /// if the data is None, will create a document with default data.
  pub fn create_document(
    &self,
    doc_id: &str,
    data: Option<DocumentData>,
  ) -> FlowyResult<Arc<MutexDocument>> {
    tracing::debug!("create a document: {:?}", doc_id);
    let uid = self.user.user_id()?;
    let db = self.user.collab_db()?;
    let collab = self.collab_builder.build(uid, doc_id, "document", db);
    let data = data.unwrap_or_else(default_document_data);
    let document = Arc::new(MutexDocument::create_with_data(collab, data)?);
    Ok(document)
  }

  /// Return the document
  pub fn get_document(&self, doc_id: &str) -> FlowyResult<Arc<MutexDocument>> {
    if let Some(doc) = self.documents.read().get(doc_id) {
      return Ok(doc.clone());
    }
    // Check if the document exists. If not, return error.
    if !self.is_doc_exist(doc_id)? {
      return Err(
        FlowyError::record_not_found().context(format!("document: {} is not exist", doc_id)),
      );
    }

    tracing::debug!("open_document: {:?}", doc_id);
    let uid = self.user.user_id()?;
    let db = self.user.collab_db()?;
    let collab = self.collab_builder.build(uid, doc_id, "document", db);
    let document = Arc::new(MutexDocument::open(doc_id, collab)?);

    // save the document to the memory and read it from the memory if we open the same document again.
    // and we don't want to subscribe to the document changes if we open the same document again.
    self
      .documents
      .write()
      .insert(doc_id.to_string(), document.clone());
    Ok(document)
  }

  pub fn get_document_data(&self, doc_id: &str) -> FlowyResult<DocumentData> {
    if !self.is_doc_exist(doc_id)? {
      return Err(
        FlowyError::record_not_found().context(format!("document: {} is not exist", doc_id)),
      );
    }

    let uid = self.user.user_id()?;
    let db = self.user.collab_db()?;
    let collab = self.collab_builder.build(uid, doc_id, "document", db);
    Document::open(collab)?
      .get_document_data()
      .map_err(internal_error)
  }

  pub fn close_document(&self, doc_id: &str) -> FlowyResult<()> {
    self.documents.write().remove(doc_id);
    Ok(())
  }

  pub fn delete_document(&self, doc_id: &str) -> FlowyResult<()> {
    let uid = self.user.user_id()?;
    let db = self.user.collab_db()?;
    let _ = db.with_write_txn(|txn| {
      txn.delete_doc(uid, &doc_id)?;
      Ok(())
    });
    self.documents.write().remove(doc_id);
    Ok(())
  }

  /// Return the list of snapshots of the document.
  pub async fn get_document_snapshots(
    &self,
    document_id: &str,
  ) -> FlowyResult<Vec<DocumentSnapshotPB>> {
    let mut snapshots = vec![];
    if let Some(snapshot) = self
      .cloud_service
      .get_latest_snapshot(document_id)
      .await?
      .map(|snapshot| DocumentSnapshotPB {
        snapshot_id: snapshot.snapshot_id,
        snapshot_desc: "".to_string(),
        created_at: snapshot.created_at,
        data: snapshot.data,
      })
    {
      snapshots.push(snapshot);
    }

    Ok(snapshots)
  }

  fn is_doc_exist(&self, doc_id: &str) -> FlowyResult<bool> {
    let uid = self.user.user_id()?;
    let db = self.user.collab_db()?;
    let read_txn = db.read_txn();
    Ok(read_txn.is_exist(uid, doc_id))
  }
}
