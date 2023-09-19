use anyhow::Error;
use lib_infra::async_trait::async_trait;

mod open_ai;
mod stability_ai;

#[async_trait]
pub trait TextCompletion: Send + Sync {
  type Input: Send + 'static;
  type Output;

  async fn text_completion(&self, params: Self::Input) -> Result<Self::Output, Error>;
}
