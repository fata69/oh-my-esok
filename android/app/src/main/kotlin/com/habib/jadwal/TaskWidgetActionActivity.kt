package com.habib.jadwal

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class TaskWidgetActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.getStringExtra(EXTRA_ACTION)) {
            ACTION_TOGGLE -> {
                val taskId = intent.getStringExtra(TaskToggleReceiver.EXTRA_TASK_ID)
                if (!taskId.isNullOrEmpty()) {
                    sendBroadcast(
                        Intent(this, TaskToggleReceiver::class.java).apply {
                            action = TaskToggleReceiver.ACTION_TOGGLE
                            putExtra(TaskToggleReceiver.EXTRA_TASK_ID, taskId)
                            putExtra(
                                TaskToggleReceiver.EXTRA_DONE,
                                intent.getBooleanExtra(
                                    TaskToggleReceiver.EXTRA_DONE,
                                    false,
                                ),
                            )
                        },
                    )
                }
            }

            ACTION_OPEN -> {
                val uri = intent.getStringExtra(EXTRA_URI)
                if (!uri.isNullOrEmpty()) {
                    startActivity(
                        Intent(this, MainActivity::class.java).apply {
                            data = Uri.parse(uri)
                            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
                            )
                        },
                    )
                }
            }
        }
        finish()
    }

    companion object {
        const val EXTRA_ACTION = "task_widget_action"
        const val EXTRA_URI = "task_widget_uri"
        const val ACTION_TOGGLE = "toggle"
        const val ACTION_OPEN = "open"
    }
}
