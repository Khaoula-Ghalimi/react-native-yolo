package com.yolo.utils

import android.content.Context
import com.margelo.nitro.NitroModules

/**
 * Provides a way to access the application context from anywhere in the app.
 * This is useful for classes that do not have a direct reference to a Context object.
 */
object ContextProvider {
    val context: Context
        get() = NitroModules.applicationContext
            ?: throw IllegalStateException("Context is null")
}