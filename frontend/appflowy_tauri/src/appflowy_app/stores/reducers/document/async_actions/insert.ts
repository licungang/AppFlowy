import { BlockType, DocumentState, NestedBlock } from '@/appflowy_app/interfaces/document';
import { DocumentController } from '$app/stores/effects/document/document_controller';
import { createAsyncThunk } from '@reduxjs/toolkit';
import { generateId } from '@/appflowy_app/utils/block';

export const insertAfterNodeThunk = createAsyncThunk(
  'document/insertAfterNode',
  async (payload: { id: string; controller: DocumentController }, thunkAPI) => {
    const { controller } = payload;
    const { dispatch, getState } = thunkAPI;
    const state = getState() as { document: DocumentState };
    const node = state.document.nodes[payload.id];
    if (!node) return;
    const parentId = node.parent;
    if (!parentId) return;
    // create new node
    const newNode: NestedBlock = {
      id: generateId(),
      parent: parentId,
      type: BlockType.TextBlock,
      data: {
        delta: [],
      },
      children: generateId(),
    };
    await controller.applyActions([controller.getInsertAction(newNode, node.id)]);
  }
);
