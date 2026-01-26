package com.mertsavaser.notecal.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import org.json.JSONObject
// MainActivity is in kotlin package, use full path

class NoteCalWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, NoteCalWidgetProvider::class.java)
            )
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val widgetDataJson = prefs.getString("flutter.notecal_widget_data", null)
        
        val views = RemoteViews(context.packageName, R.layout.widget_layout)
        
        if (widgetDataJson != null) {
            try {
                val json = JSONObject(widgetDataJson)
                val consumed = json.optInt("todayCaloriesConsumed", 0)
                val goal = json.optInt("todayCaloriesGoal", 2000)
                val mealsLogged = json.optBoolean("todayMealsLogged", false)
                val exerciseTitle = json.optString("todayLastExerciseTitle", "—")
                val hasNote = json.optBoolean("todayHasNote", false)
                val weekLoggedDays = json.optInt("weekLoggedDays", 0)
                
                // TODAY Section
                views.setTextViewText(R.id.widget_calories_consumed, consumed.toString())
                views.setTextViewText(R.id.widget_calories_goal, "/ $goal")
                views.setTextViewText(
                    R.id.widget_meals_status,
                    if (mealsLogged) "Logged" else "Not logged"
                )
                views.setTextViewText(R.id.widget_exercise_title, exerciseTitle)
                views.setViewVisibility(R.id.widget_note_icon, if (hasNote) android.view.View.VISIBLE else android.view.View.GONE)
                
                // THIS WEEK Section
                views.setTextViewText(R.id.widget_week_logged, "$weekLoggedDays/7")
            } catch (e: Exception) {
                // Handle error - show defaults
                views.setTextViewText(R.id.widget_calories_consumed, "0")
                views.setTextViewText(R.id.widget_calories_goal, "/ 2000")
            }
        } else {
            // No data - show defaults
            views.setTextViewText(R.id.widget_calories_consumed, "0")
            views.setTextViewText(R.id.widget_calories_goal, "/ 2000")
        }
        
        // Set up click intent to open app
        val intent = Intent(context, com.mertsavaser.notecal.MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pendingIntent = android.app.PendingIntent.getActivity(
            context, 0, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
