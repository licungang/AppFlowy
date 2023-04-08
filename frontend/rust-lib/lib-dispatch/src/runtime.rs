use std::{io, thread};
use tokio::runtime::{self, Runtime};

pub type AFPluginRuntime = tokio::runtime::Handle;

pub fn tokio_default_runtime() -> io::Result<Runtime> {
  runtime::Builder::new_multi_thread()
    .thread_name("dispatch-rt")
    .enable_io()
    .enable_time()
    .on_thread_start(move || {
      tracing::trace!(
        "{:?} thread started: thread_id= {}",
        thread::current(),
        thread_id::get()
      );
    })
    .on_thread_stop(move || {
      tracing::trace!(
        "{:?} thread stopping: thread_id= {}",
        thread::current(),
        thread_id::get(),
      );
    })
    .build()
}
