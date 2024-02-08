import React, { useCallback, useState } from 'react';
import { SelectOption } from '$app/application/database';
import { IconButton } from '@mui/material';
import { updateChecklistCell } from '$app/application/database/cell/cell_service';
import { useViewId } from '$app/hooks';
import { ReactComponent as DeleteIcon } from '$app/assets/delete.svg';
import { ReactComponent as CheckboxCheckSvg } from '$app/assets/database/checkbox-check.svg';
import { ReactComponent as CheckboxUncheckSvg } from '$app/assets/database/checkbox-uncheck.svg';

function ChecklistItem({
  checked,
  option,
  rowId,
  fieldId,
  onClose,
  isHovered,
  onMouseEnter,
}: {
  checked: boolean;
  option: SelectOption;
  rowId: string;
  fieldId: string;
  onClose: () => void;
  isHovered: boolean;
  onMouseEnter: () => void;
}) {
  const [value, setValue] = useState(option.name);
  const viewId = useViewId();
  const updateText = useCallback(async () => {
    await updateChecklistCell(viewId, rowId, fieldId, {
      updateOptions: [
        {
          ...option,
          name: value,
        },
      ],
    });
  }, [fieldId, option, rowId, value, viewId]);

  const onCheckedChange = useCallback(async () => {
    void updateChecklistCell(viewId, rowId, fieldId, {
      selectedOptionIds: [option.id],
    });
  }, [fieldId, option.id, rowId, viewId]);

  const deleteOption = useCallback(async () => {
    await updateChecklistCell(viewId, rowId, fieldId, {
      deleteOptionIds: [option.id],
    });
  }, [fieldId, option.id, rowId, viewId]);

  return (
    <div
      onMouseEnter={onMouseEnter}
      className={`flex items-center justify-between gap-2 rounded p-1 text-sm hover:bg-fill-list-active`}
    >
      <div className={'cursor-pointer select-none text-content-blue-400'} onClick={onCheckedChange}>
        {checked ? <CheckboxCheckSvg className={'h-5 w-5'} /> : <CheckboxUncheckSvg className={'h-5 w-5'} />}
      </div>

      <input
        className={'flex-1 truncate'}
        onBlur={updateText}
        value={value}
        onKeyDown={(e) => {
          if (e.key === 'Escape') {
            e.stopPropagation();
            e.preventDefault();
            onClose();
            return;
          }

          if (e.key === 'Enter') {
            e.stopPropagation();
            e.preventDefault();
            void updateText();
            return;
          }
        }}
        spellCheck={false}
        onChange={(e) => {
          setValue(e.target.value);
        }}
      />
      <div className={'w-10'}>
        <IconButton
          size={'small'}
          style={{
            display: isHovered ? 'block' : 'none',
          }}
          className={`z-10 mx-2`}
          onClick={deleteOption}
        >
          <DeleteIcon />
        </IconButton>
      </div>
    </div>
  );
}

export default ChecklistItem;
