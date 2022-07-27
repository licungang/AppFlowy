use crate::entities::GridTextFilter;
use crate::services::cell::{AnyCellData, CellData, CellFilterOperation};
use crate::services::field::{TextCellData, URLTypeOption};
use flowy_error::FlowyResult;

impl CellFilterOperation<GridTextFilter> for URLTypeOption {
    fn apply_filter(&self, any_cell_data: AnyCellData, filter: &GridTextFilter) -> FlowyResult<bool> {
        if !any_cell_data.is_url() {
            return Ok(true);
        }

        let cell_data: CellData<TextCellData> = any_cell_data.into();
        let text_cell_data = cell_data.try_into_inner()?;
        Ok(filter.is_visible(&text_cell_data))
    }
}
