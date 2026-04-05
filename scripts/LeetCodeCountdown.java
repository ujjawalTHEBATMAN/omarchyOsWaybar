import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;

public class LeetCodeCountdown {
    public static void main(String[] args) {
        ZoneId zone = ZoneId.systemDefault();
        LocalDateTime now = LocalDateTime.now(zone);
        LocalDateTime target = LocalDate.now(zone).atTime(LocalTime.of(6, 0));

        if (!now.isBefore(target)) {
            target = target.plusDays(1);
        }

        Duration remaining = Duration.between(now, target);
        long totalMinutes = remaining.toMinutes();
        long hours = totalMinutes / 60;
        long minutes = totalMinutes % 60;

        String text = String.format("LC %02dh %02dm", hours, minutes);
        String tooltip = String.format(
            "LeetCode Virtual Contest\nNext launch: %s\nTimezone: %s",
            target.format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")),
            zone
        );

        // Emit strict Waybar-compatible JSON.
        String json = String.format(
            "{\"text\":\"%s\",\"tooltip\":\"%s\"}",
            escapeJson(text),
            escapeJson(tooltip)
        );
        System.out.println(json);
    }

    private static String escapeJson(String s) {
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }
}
