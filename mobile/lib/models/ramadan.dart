import 'package:hijri/hijri_calendar.dart';

enum RamadanPromptKind { turnOn, turnOff }

/// A suggestion to turn Ramadan mode on or off. [key] names it, so a dismissed one stays dismissed.
class RamadanPrompt {
  const RamadanPrompt(this.kind, this.hijriYear);

  final RamadanPromptKind kind;
  final int hijriYear;

  String get key => '${kind.name}-$hijriYear';
}

/// 1 Ramadan and 1 Shawwal of [hijriYear], from the Umm al-Qura calendar, offline. Countries can
/// differ by a day, which is why the app only suggests and never switches by itself.
({DateTime start, DateTime end}) ramadanDates(int hijriYear) {
  final calendar = HijriCalendar();
  return (start: calendar.hijriToGregorian(hijriYear, 9, 1), end: calendar.hijriToGregorian(hijriYear, 10, 1));
}

/// How many days before 1 Ramadan the app starts suggesting the mode.
const ramadanLeadDays = 3;

/// How long after Ramadan the app suggests turning the mode off.
const ramadanOffDays = 14;

/// The suggestion due on [today], if any.
RamadanPrompt? ramadanPromptFor(DateTime today, {required bool modeOn, required Set<String> dismissed}) {
  final day = DateTime(today.year, today.month, today.day);
  final year = HijriCalendar.fromDate(day).hYear;
  for (final y in [year - 1, year, year + 1]) {
    final dates = ramadanDates(y);
    final onFrom = DateTime(dates.start.year, dates.start.month, dates.start.day - ramadanLeadDays);
    final offUntil = DateTime(dates.end.year, dates.end.month, dates.end.day + ramadanOffDays);
    if (!modeOn && !day.isBefore(onFrom) && day.isBefore(dates.end)) {
      final prompt = RamadanPrompt(RamadanPromptKind.turnOn, y);
      if (!dismissed.contains(prompt.key)) return prompt;
    }
    if (modeOn && !day.isBefore(dates.end) && day.isBefore(offUntil)) {
      final prompt = RamadanPrompt(RamadanPromptKind.turnOff, y);
      if (!dismissed.contains(prompt.key)) return prompt;
    }
  }
  return null;
}
