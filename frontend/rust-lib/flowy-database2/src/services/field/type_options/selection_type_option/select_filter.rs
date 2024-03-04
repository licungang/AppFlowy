use crate::entities::{SelectOptionConditionPB, SelectOptionFilterPB};
use crate::services::field::SelectOption;

impl SelectOptionFilterPB {
  pub fn is_visible(&self, selected_options: &[SelectOption]) -> Option<bool> {
    let selected_option_ids = selected_options
      .iter()
      .map(|option| &option.id)
      .collect::<Vec<_>>();

    let get_non_empty_expected_options =
      || (!self.option_ids.is_empty()).then(|| self.option_ids.clone());

    let strategy = match self.condition {
      SelectOptionConditionPB::OptionIs => {
        SelectOptionFilterStrategy::Is(get_non_empty_expected_options()?)
      },
      SelectOptionConditionPB::OptionIsNot => {
        SelectOptionFilterStrategy::IsNot(get_non_empty_expected_options()?)
      },
      SelectOptionConditionPB::OptionContains => {
        SelectOptionFilterStrategy::Contains(get_non_empty_expected_options()?)
      },
      SelectOptionConditionPB::OptionDoesNotContain => {
        SelectOptionFilterStrategy::DoesNotContain(get_non_empty_expected_options()?)
      },
      SelectOptionConditionPB::OptionIsEmpty => SelectOptionFilterStrategy::IsEmpty,
      SelectOptionConditionPB::OptionIsNotEmpty => SelectOptionFilterStrategy::IsNotEmpty,
    };

    Some(strategy.filter(&selected_option_ids))
  }
}

enum SelectOptionFilterStrategy {
  Is(Vec<String>),
  IsNot(Vec<String>),
  Contains(Vec<String>),
  DoesNotContain(Vec<String>),
  IsEmpty,
  IsNotEmpty,
}

impl SelectOptionFilterStrategy {
  fn filter(self, selected_option_ids: &[&String]) -> bool {
    match self {
      SelectOptionFilterStrategy::Is(option_ids) => {
        if selected_option_ids.is_empty() {
          return false;
        }

        selected_option_ids.len() == option_ids.len()
          && selected_option_ids.iter().all(|id| option_ids.contains(id))
      },
      SelectOptionFilterStrategy::IsNot(option_ids) => {
        if selected_option_ids.is_empty() {
          return true;
        }

        selected_option_ids.len() != option_ids.len()
          || !selected_option_ids.iter().all(|id| option_ids.contains(id))
      },
      SelectOptionFilterStrategy::Contains(option_ids) => {
        if selected_option_ids.is_empty() {
          return false;
        }

        let required_options = option_ids
          .into_iter()
          .filter(|id| selected_option_ids.contains(&id))
          .collect::<Vec<_>>();

        !required_options.is_empty()
      },
      SelectOptionFilterStrategy::DoesNotContain(option_ids) => {
        if selected_option_ids.is_empty() {
          return true;
        }

        let required_options = option_ids
          .into_iter()
          .filter(|id| selected_option_ids.contains(&id))
          .collect::<Vec<_>>();

        required_options.is_empty()
      },
      SelectOptionFilterStrategy::IsEmpty => selected_option_ids.is_empty(),
      SelectOptionFilterStrategy::IsNotEmpty => !selected_option_ids.is_empty(),
    }
  }
}

#[cfg(test)]
mod tests {
  use crate::entities::{SelectOptionConditionPB, SelectOptionFilterPB};
  use crate::services::field::SelectOption;

  #[test]
  fn select_option_filter_is_empty_test() {
    let option = SelectOption::new("A");
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIsEmpty,
      option_ids: vec![],
    };

    assert_eq!(filter.is_visible(&[]), Some(true));
    assert_eq!(filter.is_visible(&[option.clone()]), Some(false));
  }

  #[test]
  fn select_option_filter_is_not_empty_test() {
    let option_1 = SelectOption::new("A");
    let option_2 = SelectOption::new("B");
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIsNotEmpty,
      option_ids: vec![option_1.id.clone(), option_2.id.clone()],
    };

    assert_eq!(filter.is_visible(&[]), Some(false));
    assert_eq!(filter.is_visible(&[option_1.clone()]), Some(true));
  }

  #[test]
  fn select_option_filter_is_test() {
    let option_1 = SelectOption::new("A");
    let option_2 = SelectOption::new("B");
    let option_3 = SelectOption::new("C");

    // no expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIs,
      option_ids: vec![],
    };
    for (options, is_visible) in [
      (vec![], None),
      (vec![option_1.clone()], None),
      (vec![option_1.clone(), option_2.clone()], None),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // one expected option
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIs,
      option_ids: vec![option_1.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(false)),
      (vec![option_1.clone()], Some(true)),
      (vec![option_2.clone()], Some(false)),
      (vec![option_3.clone()], Some(false)),
      (vec![option_1.clone(), option_2.clone()], Some(false)),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // multiple expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIs,
      option_ids: vec![option_1.id.clone(), option_2.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(false)),
      (vec![option_1.clone()], Some(false)),
      (vec![option_1.clone(), option_2.clone()], Some(true)),
      (
        vec![option_1.clone(), option_2.clone(), option_3.clone()],
        Some(false),
      ),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }
  }

  #[test]
  fn select_option_filter_is_not_test() {
    let option_1 = SelectOption::new("A");
    let option_2 = SelectOption::new("B");
    let option_3 = SelectOption::new("C");

    // no expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIsNot,
      option_ids: vec![],
    };
    for (options, is_visible) in [
      (vec![], None),
      (vec![option_1.clone()], None),
      (vec![option_1.clone(), option_2.clone()], None),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // one expected option
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIsNot,
      option_ids: vec![option_1.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(true)),
      (vec![option_1.clone()], Some(false)),
      (vec![option_2.clone()], Some(true)),
      (vec![option_3.clone()], Some(true)),
      (vec![option_1.clone(), option_2.clone()], Some(true)),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // multiple expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionIsNot,
      option_ids: vec![option_1.id.clone(), option_2.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(true)),
      (vec![option_1.clone()], Some(true)),
      (vec![option_1.clone(), option_2.clone()], Some(false)),
      (
        vec![option_1.clone(), option_2.clone(), option_3.clone()],
        Some(true),
      ),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }
  }

  #[test]
  fn select_option_filter_contains_test() {
    let option_1 = SelectOption::new("A");
    let option_2 = SelectOption::new("B");
    let option_3 = SelectOption::new("C");
    let option_4 = SelectOption::new("D");

    // no expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionContains,
      option_ids: vec![],
    };
    for (options, is_visible) in [
      (vec![], None),
      (vec![option_1.clone()], None),
      (vec![option_1.clone(), option_2.clone()], None),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // one expected option
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionContains,
      option_ids: vec![option_1.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(false)),
      (vec![option_1.clone()], Some(true)),
      (vec![option_2.clone()], Some(false)),
      (vec![option_1.clone(), option_2.clone()], Some(true)),
      (vec![option_3.clone(), option_4.clone()], Some(false)),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // multiple expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionContains,
      option_ids: vec![option_1.id.clone(), option_2.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(false)),
      (vec![option_1.clone()], Some(true)),
      (vec![option_3.clone()], Some(false)),
      (vec![option_1.clone(), option_2.clone()], Some(true)),
      (vec![option_1.clone(), option_3.clone()], Some(true)),
      (vec![option_3.clone(), option_4.clone()], Some(false)),
      (
        vec![option_1.clone(), option_3.clone(), option_4.clone()],
        Some(true),
      ),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }
  }

  #[test]
  fn select_option_filter_does_not_contain_test() {
    let option_1 = SelectOption::new("A");
    let option_2 = SelectOption::new("B");
    let option_3 = SelectOption::new("C");
    let option_4 = SelectOption::new("D");

    // no expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionDoesNotContain,
      option_ids: vec![],
    };
    for (options, is_visible) in [
      (vec![], None),
      (vec![option_1.clone()], None),
      (vec![option_1.clone(), option_2.clone()], None),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // one expected option
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionDoesNotContain,
      option_ids: vec![option_1.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(true)),
      (vec![option_1.clone()], Some(false)),
      (vec![option_2.clone()], Some(true)),
      (vec![option_1.clone(), option_2.clone()], Some(false)),
      (vec![option_3.clone(), option_4.clone()], Some(true)),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }

    // multiple expected options
    let filter = SelectOptionFilterPB {
      condition: SelectOptionConditionPB::OptionDoesNotContain,
      option_ids: vec![option_1.id.clone(), option_2.id.clone()],
    };
    for (options, is_visible) in [
      (vec![], Some(true)),
      (vec![option_1.clone()], Some(false)),
      (vec![option_3.clone()], Some(true)),
      (vec![option_1.clone(), option_2.clone()], Some(false)),
      (vec![option_1.clone(), option_3.clone()], Some(false)),
      (vec![option_3.clone(), option_4.clone()], Some(true)),
      (
        vec![option_1.clone(), option_3.clone(), option_4.clone()],
        Some(false),
      ),
    ] {
      assert_eq!(filter.is_visible(&options), is_visible);
    }
  }
}
