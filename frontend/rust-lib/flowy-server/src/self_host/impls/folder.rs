use anyhow::Error;
use flowy_folder_deps::cloud::{
  gen_workspace_id, FolderCloudService, FolderData, FolderSnapshot, Workspace,
};
use lib_infra::future::FutureResult;
use lib_infra::util::timestamp;

pub(crate) struct SelfHostedServerFolderCloudServiceImpl();

impl FolderCloudService for SelfHostedServerFolderCloudServiceImpl {
  fn create_workspace(&self, _uid: i64, name: &str) -> FutureResult<Workspace, Error> {
    let name = name.to_string();
    FutureResult::new(async move {
      Ok(Workspace {
        id: gen_workspace_id(),
        name: name.to_string(),
        child_views: Default::default(),
        created_at: timestamp(),
      })
    })
  }

  fn add_member_to_workspace(&self, _email: &str, _workspace_id: &str) -> FutureResult<(), Error> {
    FutureResult::new(async move { Ok(()) })
  }

  fn remove_member_from_workspace(
    &self,
    _email: &str,
    _workspace_id: &str,
  ) -> FutureResult<(), Error> {
    FutureResult::new(async move { Ok(()) })
  }

  fn get_folder_data(&self, _workspace_id: &str) -> FutureResult<Option<FolderData>, Error> {
    FutureResult::new(async move { Ok(None) })
  }

  fn get_folder_latest_snapshot(
    &self,
    _workspace_id: &str,
  ) -> FutureResult<Option<FolderSnapshot>, Error> {
    FutureResult::new(async move { Ok(None) })
  }

  fn get_folder_updates(
    &self,
    _workspace_id: &str,
    _uid: i64,
  ) -> FutureResult<Vec<Vec<u8>>, Error> {
    FutureResult::new(async move { Ok(vec![]) })
  }

  fn service_name(&self) -> String {
    "SelfHosted".to_string()
  }
}
