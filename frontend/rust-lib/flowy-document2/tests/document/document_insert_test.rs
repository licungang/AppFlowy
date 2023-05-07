use std::{collections::HashMap, sync::Arc, vec};

use collab_document::blocks::{Block, BlockAction, BlockActionPayload, BlockActionType};
use flowy_document2::{
  document::Document, document_data::DocumentDataWrapper, manager::DocumentManager,
};
use nanoid::nanoid;

use super::util::FakeUser;

#[test]
fn document_apply_insert_block_with_empty_parent_id() {
  let (_, document, page_id) = create_and_open_empty_document();

  // create a text block with no parent
  let text_block_id = nanoid!(10);
  let text_block = Block {
    id: text_block_id.clone(),
    ty: "text".to_string(),
    parent: "".to_string(),
    children: nanoid!(10),
    external_id: None,
    external_type: None,
    data: HashMap::new(),
  };
  let insert_text_action = BlockAction {
    action: BlockActionType::Insert,
    payload: BlockActionPayload {
      block: text_block,
      parent_id: Some(page_id.clone()),
      prev_id: None,
    },
  };
  document.lock().apply_action(vec![insert_text_action]);

  // read the text block and it's parent id should be the page id
  let block = document.lock().get_block(&text_block_id).unwrap();
  assert_eq!(block.parent, page_id);
}

fn create_and_open_empty_document() -> (DocumentManager, Arc<Document>, String) {
  let user = FakeUser::new();
  let manager = DocumentManager::new(Arc::new(user));

  let doc_id: String = nanoid!(10);
  let data = DocumentDataWrapper::default();

  // create a document
  _ = manager
    .create_document(doc_id.clone(), data.clone())
    .unwrap();

  let document = manager.open_document(doc_id.clone()).unwrap();

  (manager, document, data.0.page_id)
}
