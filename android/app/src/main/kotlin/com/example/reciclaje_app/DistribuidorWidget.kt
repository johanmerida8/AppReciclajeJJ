package com.example.reciclaje_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class DistribuidorWidget : AppWidgetProvider() {

    // Función para actualizar el RemoteViews (layout + datos + clic)
    private fun actualizarWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, layoutId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val puntos = prefs.getInt("puntos", 0)
        val ranking = prefs.getInt("ranking", 0)

        val views = RemoteViews(context.packageName, layoutId)

        // Actualizamos los textos
        views.setTextViewText(R.id.txtPuntos, puntos.toString())
        views.setTextViewText(R.id.txtRanking, "#$ranking")

        // PendingIntent para abrir MainActivity al tocar el widget
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    // Actualización inicial del widget
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Por defecto usamos layout para 3+ celdas
            actualizarWidget(context, appWidgetManager, appWidgetId, R.layout.widget_distribuidor)
        }
    }

    // Detecta cambios de tamaño y cambia el layout automáticamente
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        val minWidth = newOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)

        val layoutId = if (minWidth < 120) {
            // Layout para 2 celdas
            R.layout.widget_distribuidor2
        } else {
            // Layout para 3 o más celdas
            R.layout.widget_distribuidor
        }

        // Actualizamos el widget con el layout adecuado
        actualizarWidget(context, appWidgetManager, appWidgetId, layoutId)
    }
}
