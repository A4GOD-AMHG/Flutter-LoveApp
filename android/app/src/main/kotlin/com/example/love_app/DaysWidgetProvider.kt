package loveapp.flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.Calendar

/** Widget de pantalla de inicio: corazón con los días juntos, como en Inicio. */
class DaysWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val days = daysTogether(Calendar.getInstance())
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val views = RemoteViews(context.packageName, R.layout.days_widget).apply {
            setTextViewText(R.id.days_text, days.toString())
            setOnClickPendingIntent(R.id.widget_root, openApp)
        }
        ids.forEach { manager.updateAppWidget(it, views) }
    }

    companion object {
        // Debe coincidir con HomeScreen._startDate en lib/screens/home_screen.dart.
        private const val START_YEAR = 2024
        private const val START_MONTH = Calendar.JANUARY
        private const val START_DAY = 27

        /** Días de calendario desde el inicio; redondeo para tolerar días de 23/25 h por horario de verano. */
        fun daysTogether(today: Calendar): Long {
            val start = Calendar.getInstance(today.timeZone).apply {
                clear()
                set(START_YEAR, START_MONTH, START_DAY)
            }
            val todayMidnight = (today.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            }
            return Math.round((todayMidnight.timeInMillis - start.timeInMillis) / 86_400_000.0)
        }
    }
}
