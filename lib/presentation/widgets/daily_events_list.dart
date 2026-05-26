import 'package:flutter/material.dart';
import '../../domain/usecases/calculate_daily_events_usecase.dart';
import '../bloc_or_provider/home_cubit.dart';
import 'greeting_canvas.dart';

class DailyEventsList extends StatelessWidget {
  final List<DailyEventResult> events;
  final HomeCubit cubit;
  final String? spreadsheetId;

  const DailyEventsList({super.key, required this.events, required this.cubit, required this.spreadsheetId});

  @override
  Widget build(BuildContext context) {
    // יצירת עותק של הרשימה ומיון דינמי: אירועים שלא נשלחו יהיו למעלה, ואירועים שנשלחו ירדו לסוף
    final List<DailyEventResult> sortedEvents = List.from(events)
      ..sort((a, b) {
        bool aSent = false;
        if (a.event.sentTimestamp.isNotEmpty) {
          final DateTime? sentDate = DateTime.tryParse(a.event.sentTimestamp);
          if (sentDate != null && sentDate.year == DateTime.now().year) {
            aSent = true;
          }
        }

        bool bSent = false;
        if (b.event.sentTimestamp.isNotEmpty) {
          final DateTime? sentDate = DateTime.tryParse(b.event.sentTimestamp);
          if (sentDate != null && sentDate.year == DateTime.now().year) {
            bSent = true;
          }
        }

        // אם מצב השליחה זהה, שומרים על הסדר המקורי.
        // אם אחד נשלח והשני לא - זה שלא נשלח (false) מקבל קדימות ועולה למעלה.
        if (aSent == bSent) return 0;
        return aSent ? 1 : -1;
      });

    // מעתה והלאה הפונקציה משתמשת ברשימה הממוינת sortedEvents במקום ב-events המקורי
    if (sortedEvents.isEmpty) {
      return const Center(
        child: Text(
          'אין ברכות או אירועים המתוזמנים להיום.\nיום שקט ומוצלח!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        final e = sortedEvents[index];

        // תיקון כפילות הפתיח: מתחילים ישירות מגוף האיחול
        final String defaultText = 'רציתי לאחל לך המון מזל טוב לרגל ${e.event.eventType}! ✨';

        final isBirthday = e.event.eventType.trim() == 'יום הולדת';
        final Color eventColor = isBirthday ? const Color(0xFF8B1E3F) : const Color(0xFFC5A880);
        final String eventEmoji = isBirthday ? '🎂 ' : '🏡 ';

        // קביעת צבעי תגית הסטטוס (אירוע של היום / תזכורת מוקדמת)
        final Color statusBgColor = e.isEarlyReminder ? Colors.orange.shade50 : Colors.green.shade50;
        final Color statusTextColor = e.isEarlyReminder ? Colors.orange.shade800 : Colors.green.shade800;

        // בדיקה האם האירוע כבר נשלח בשנה הנוכחית
        bool isSentThisYear = false;
        if (e.event.sentTimestamp.isNotEmpty) {
          final DateTime? sentDate = DateTime.tryParse(e.event.sentTimestamp);
          if (sentDate != null && sentDate.year == DateTime.now().year) {
            isSentThisYear = true;
          }
        }

        return Opacity(
          opacity: isSentThisYear ? 0.5 : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
              border: Border(
                left: BorderSide(color: eventColor, width: 5), // פס צבע אנכי שמאלי
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              title: Row(
                children: [
                  Expanded(
                    child: Text(e.client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: eventColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '$eventEmoji${e.event.eventType}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: eventColor),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // הפיכת הודעת הסטטוס המקורית לתגית מעוגלת ועדינה
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusBgColor, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        e.displayMessage,
                        style: TextStyle(color: statusTextColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // שורות המידע עם אייקונים, ריווח והדגשת כותרות הנתונים
                    if (e.event.address.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 15, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black87, fontFamily: 'Roboto'),
                                children: [
                                  const TextSpan(
                                    text: 'נכס: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: e.event.address),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (e.event.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.notes_rounded, size: 15, color: Colors.black45),
                          const SizedBox(width: 6),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 13, color: Colors.black54, fontFamily: 'Roboto'),
                                children: [
                                  const TextSpan(
                                    text: 'הערות: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(text: e.event.notes),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              trailing: isSentThisYear
                  ? InkWell(
                      onTap: () {
                        if (spreadsheetId != null) {
                          cubit.cancelEventSentStatus(spreadsheetId: spreadsheetId!, event: e.event);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'נשלח',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                          builder: (context) => Padding(
                            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                            child: GreetingCanvas(client: e.client, event: e.event, defaultGreetingText: defaultText, logoAssetPath: 'assets/images/logo.png', cubit: cubit, spreadsheetId: spreadsheetId ?? ''),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5565),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                      label: const Text('ברכה', style: TextStyle(color: Colors.white, fontSize: 13)),
                    ),
            ),
          ),
        );
      },
    );
  }
}
