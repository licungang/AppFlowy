use std::{
  ops::{Deref, DerefMut},
  sync::Arc,
};

use collab::core::collab::MutexCollab;
use collab_document::{blocks::DocumentData, document::Document};
use futures::StreamExt;
use parking_lot::Mutex;
use tokio_stream::wrappers::WatchStream;

use flowy_error::FlowyResult;

use crate::entities::{DocEventPB, DocumentSnapshotStatePB};
use crate::notification::{send_notification, DocumentNotification};

/// This struct wrap the document::Document
#[derive(Clone)]
pub struct MutexDocument(Arc<Mutex<Document>>);

impl MutexDocument {
  /// Open a document with the given collab.
  /// # Arguments
  /// * `collab` - the identifier of the collaboration instance
  ///
  /// # Returns
  /// * `Result<Document, FlowyError>` - a Result containing either a new Document object or an Error if the document creation failed
  pub fn open(doc_id: &str, collab: Arc<MutexCollab>) -> FlowyResult<Self> {
    let document = Document::open(collab.clone()).map(|inner| Self(Arc::new(Mutex::new(inner))))?;
    subscribe_document_changed(doc_id, &document);
    subscribe_document_snapshot_state(&collab);
    Ok(document)
  }

  /// Creates and returns a new Document object with initial data.
  /// # Arguments
  /// * `collab` - the identifier of the collaboration instance
  /// * `data` - the initial data to include in the document
  ///
  /// # Returns
  /// * `Result<Document, FlowyError>` - a Result containing either a new Document object or an Error if the document creation failed
  pub fn create_with_data(collab: Arc<MutexCollab>, data: DocumentData) -> FlowyResult<Self> {
    let document = Document::create_with_data(collab.clone(), data)
      .map(|inner| Self(Arc::new(Mutex::new(inner))))?;
    Ok(document)
  }
}

fn subscribe_document_changed(doc_id: &str, document: &MutexDocument) {
  let doc_id = doc_id.to_string();
  document
    .lock()
    .subscribe_block_changed(move |events, is_remote| {
      tracing::trace!(
        "document changed: {:?}, from remote: {}",
        &events,
        is_remote
      );
      // send notification to the client.
      send_notification(&doc_id, DocumentNotification::DidReceiveUpdate)
        .payload::<DocEventPB>((events, is_remote).into())
        .send();
    });
}

fn subscribe_document_snapshot_state(collab: &Arc<MutexCollab>) {
  let document_id = collab.lock().object_id.clone();
  let mut snapshot_state = WatchStream::new(collab.lock().subscribe_snapshot_state());
  tokio::spawn(async move {
    while let Some(snapshot_state) = snapshot_state.next().await {
      send_notification(
        &document_id,
        DocumentNotification::DidUpdateDocumentSnapshotState,
      )
      .payload(DocumentSnapshotStatePB::from(snapshot_state))
      .send();
    }
  });
}

unsafe impl Sync for MutexDocument {}
unsafe impl Send for MutexDocument {}

impl Deref for MutexDocument {
  type Target = Arc<Mutex<Document>>;

  fn deref(&self) -> &Self::Target {
    &self.0
  }
}

impl DerefMut for MutexDocument {
  fn deref_mut(&mut self) -> &mut Self::Target {
    &mut self.0
  }
}
