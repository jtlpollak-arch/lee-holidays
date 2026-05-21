import 'package:flutter/material.dart';
import '../../../data/models/event_model.dart';
import '../../../data/models/client_model.dart';

class CVDeleteDialog extends StatelessWidget {
  final EventModel event;
  final ClientModel client;
  final VoidCallback onDeleteConfirmed;

  const CVDeleteDialog({super.key, required this.event, required this.client, required this.onDeleteConfirmed});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('מחיקת אירוע'),
        content: Text('האם את בטוחה שברצונך למחוק את האירוע "${event.eventType}" של ${client.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ביטול')),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              onDeleteConfirmed();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('מחקי'),
          ),
        ],
      ),
    );
  }
}
