package com.anton111111.dtsfixer;

import android.content.Context;
import android.content.SharedPreferences;

final class BootSettings {
    static final String PREFERENCES = "dts_boot_settings";
    static final String KEY_MODE = "mode";
    static final String KEY_SILENT = "silent";
    static final String KEY_DELAY_SECONDS = "delay_seconds";
    static final int DEFAULT_DELAY_SECONDS = 3;
    static final int MAX_DELAY_SECONDS = 120;

    private BootSettings() {
    }

    static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
    }

    static int delaySeconds(SharedPreferences preferences) {
        return sanitizeDelay(preferences.getInt(KEY_DELAY_SECONDS, DEFAULT_DELAY_SECONDS));
    }

    static int sanitizeDelay(int value) {
        return Math.max(0, Math.min(value, MAX_DELAY_SECONDS));
    }

    enum Mode {
        RESET_DTS("reset_dts"),
        THEATRE_FULL_CAR("theatre_full_car");

        final String value;

        Mode(String value) {
            this.value = value;
        }

        static Mode fromValue(String value) {
            return THEATRE_FULL_CAR.value.equals(value) ? THEATRE_FULL_CAR : RESET_DTS;
        }
    }
}