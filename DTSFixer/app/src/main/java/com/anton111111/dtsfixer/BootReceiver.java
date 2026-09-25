package com.anton111111.dtsfixer;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            return;
        }

        BootSettings.Mode mode = BootSettings.Mode.fromValue(
                BootSettings.preferences(context).getString(
                        BootSettings.KEY_MODE, BootSettings.Mode.RESET_DTS.value));
        boolean silent = BootSettings.preferences(context).getBoolean(BootSettings.KEY_SILENT, false);
        long delayMillis = BootSettings.delaySeconds(BootSettings.preferences(context)) * 1000L;
        PendingResult pendingResult = goAsync();
        Context appContext = context.getApplicationContext();

        new Handler(Looper.getMainLooper()).postDelayed(() ->
                DtsController.run(appContext, mode, outcome -> {
                    if (!silent) {
                        Toast.makeText(appContext, outcome.message, Toast.LENGTH_LONG).show();
                    }
                    pendingResult.finish();
                }), delayMillis);
    }
}