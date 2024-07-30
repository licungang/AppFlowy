import 'package:appflowy/mobile/presentation/notifications/widgets/_notification_item.dart';
import 'package:appflowy/user/application/reminder/reminder_bloc.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NotificationInboxTab extends StatefulWidget {
  const NotificationInboxTab({super.key});

  @override
  State<NotificationInboxTab> createState() => _NotificationInboxTabState();
}

class _NotificationInboxTabState extends State<NotificationInboxTab> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReminderBloc, ReminderState>(
      builder: (context, state) {
        return ListView.separated(
          itemCount: state.reminders.length,
          separatorBuilder: (context, index) => const VSpace(8.0),
          itemBuilder: (context, index) {
            final reminders = state.reminders.reversed.toList();
            final reminder = reminders[index];
            return NotificationItem(
              key: ValueKey('inbox_${reminder.id}'),
              reminder: reminder,
            );
          },
        );
      },
    );
  }
}
