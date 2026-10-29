package com.example.studyassistant

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import org.json.JSONArray
import java.time.Duration
import java.time.Instant
import java.time.OffsetDateTime

class AssignmentWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, buildViews(context))
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.assignment_widget)
        val items = loadItems(context)
        if (items.length() == 0) {
            views.setTextViewText(R.id.assignment_title_1, "暂无作业")
            views.setTextViewText(R.id.assignment_meta_1, "打开 App 同步学习通")
            views.setTextViewText(R.id.assignment_title_2, "")
            views.setTextViewText(R.id.assignment_meta_2, "")
        } else {
            val first = items.getJSONObject(0)
            views.setTextViewText(R.id.assignment_title_1, first.optString("title"))
            views.setTextViewText(R.id.assignment_meta_1, metaText(first))
            setAssignmentClick(context, views, R.id.assignment_title_1, first, 1)
            setAssignmentClick(context, views, R.id.assignment_meta_1, first, 2)
            if (items.length() > 1) {
                val second = items.getJSONObject(1)
                views.setTextViewText(R.id.assignment_title_2, second.optString("title"))
                views.setTextViewText(R.id.assignment_meta_2, metaText(second))
                setAssignmentClick(context, views, R.id.assignment_title_2, second, 3)
                setAssignmentClick(context, views, R.id.assignment_meta_2, second, 4)
            } else {
                views.setTextViewText(R.id.assignment_title_2, "")
                views.setTextViewText(R.id.assignment_meta_2, "")
            }
        }

        val target = if (items.length() > 0) {
            items.getJSONObject(0).optString("deepLinkUrl", "studyassistant://assignments")
        } else {
            "studyassistant://assignments"
        }
        val intent = Intent(Intent.ACTION_VIEW, normalizeDeepLink(target)).setPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.assignment_widget_root, pendingIntent)
        return views
    }

    private fun metaText(item: org.json.JSONObject): String {
        val remaining = item.optString("deadlineAt").let { deadline ->
            if (deadline.isBlank()) {
                item.optString("remainingText")
            } else {
                remainingText(deadline).ifBlank { item.optString("remainingText") }
            }
        }
        return "${item.optString("courseName")} · $remaining"
    }

    private fun remainingText(rawDeadline: String): String {
        val deadline = try {
            OffsetDateTime.parse(rawDeadline).toInstant()
        } catch (_: Exception) {
            try { Instant.parse(rawDeadline) } catch (_: Exception) { return "" }
        }
        val minutes = Duration.between(Instant.now(), deadline).toMinutes()
        if (minutes <= 0) return "已截止"
        if (minutes < 60) return "${minutes}分钟"
        val hours = (minutes + 59) / 60
        if (hours < 24) return "${hours}小时"
        return "${(hours + 23) / 24}天"
    }

    private fun setAssignmentClick(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        item: org.json.JSONObject,
        requestCode: Int,
    ) {
        val target = item.optString("deepLinkUrl", "studyassistant://assignments")
        val intent = Intent(Intent.ACTION_VIEW, normalizeDeepLink(target)).setPackage(context.packageName)
        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(viewId, pendingIntent)
    }

    private fun normalizeDeepLink(target: String): Uri {
        if (target.startsWith("studyassistant://assignments/")) {
            return Uri.parse(target.replaceFirst("studyassistant://assignments/", "studyassistant:///assignments/"))
        }
        if (target == "studyassistant://assignments") {
            return Uri.parse("studyassistant:///assignments")
        }
        return Uri.parse(target)
    }

    private fun loadItems(context: Context): JSONArray {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("assignment_snapshot", "[]") ?: "[]"
        return try {
            JSONArray(raw)
        } catch (_: Exception) {
            JSONArray()
        }
    }
}
