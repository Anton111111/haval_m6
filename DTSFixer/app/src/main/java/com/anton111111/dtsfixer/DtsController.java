package com.anton111111.dtsfixer;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Parcel;
import android.os.RemoteException;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

final class DtsController {
    private static final String SETTINGS_SERVICE_PACKAGE = "com.adayo.midware.settings";
    private static final String SETTINGS_SERVICE_CLASS =
            "com.adayo.midware.settings.service.SettingsSvc";
    private static final String SETTINGS_SERVICE_ACTION =
            "com.adayo.midware.settings.service.action.SETTINGS_SERVICE_START";
    private static final String SETTINGS_INTERFACE =
            "com.adayo.proxy.settings.aidl.ISettingsSvcInterfaceAIDL";
    private static final int TRANSACTION_DTS_TYPE = 0x26;
    private static final int MODE_SET = 0;
    private static final int MODE_GET = 1;
    private static final long SWITCH_DELAY_MS = 700L;

    interface Callback {
        void onComplete(Outcome outcome);
    }

    static void run(Context context, BootSettings.Mode mode, Callback callback) {
        new DtsController(context.getApplicationContext(), mode, callback).start();
    }

    private final Context context;
    private final BootSettings.Mode mode;
    private final Callback callback;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private boolean bound;

    private final ServiceConnection connection = new ServiceConnection() {
        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            executor.execute(() -> completeOnMain(runMode(service)));
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            completeOnMain(Outcome.failure("Сервис DTS отключён."));
        }
    };

    private DtsController(Context context, BootSettings.Mode mode, Callback callback) {
        this.context = context;
        this.mode = mode;
        this.callback = callback;
    }

    private void start() {
        Intent intent = new Intent(SETTINGS_SERVICE_ACTION)
                .setComponent(new ComponentName(SETTINGS_SERVICE_PACKAGE, SETTINGS_SERVICE_CLASS));
        bound = context.bindService(intent, connection, Context.BIND_AUTO_CREATE);
        if (!bound) {
            completeOnMain(Outcome.failure("Не удалось подключиться к сервису DTS."));
        }
    }

    private Outcome runMode(IBinder binder) {
        try {
            DtsResult current = callDtsType(binder, MODE_GET, new String[0], 2);
            String currentValue = current.valueAt(0);
            if (current.code != 0 || currentValue == null) {
                return Outcome.failure("Не удалось прочитать режим DTS. Код=" + current.code);
            }

            if (mode == BootSettings.Mode.RESET_DTS) {
                if ("0".equals(currentValue)) {
                    return Outcome.success("DTS отключён, действие не требуется.");
                }
                return switchModeAndRestore(binder, currentValue, "0", "Сброс DTS выполнен.");
            }

            String temporaryValue = "1".equals(currentValue) ? "8" : "1";
            return switchModeAndRestore(binder, currentValue, temporaryValue,
                    "Переключение DTS Theatre / Весь салон выполнено.");
        } catch (RemoteException exception) {
                return Outcome.failure("Ошибка Binder DTS: " + exception.getMessage());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            return Outcome.failure("Операция DTS была прервана.");
        } catch (RuntimeException exception) {
            return Outcome.failure("Ошибка DTS: " + exception.getMessage());
        }
    }

    private Outcome switchModeAndRestore(IBinder binder, String currentValue, String temporaryValue,
                                         String successMessage)
            throws RemoteException, InterruptedException {
        DtsResult change = callDtsType(binder, MODE_SET, new String[]{temporaryValue}, 0);
        Thread.sleep(SWITCH_DELAY_MS);
        DtsResult restore = callDtsType(binder, MODE_SET, new String[]{currentValue}, 0);
        if (change.code == 0 && restore.code == 0) {
            return Outcome.success(successMessage);
        }
        return Outcome.failure("Команда DTS не выполнена. Коды=" + change.code + "/" + restore.code);
    }

    private DtsResult callDtsType(IBinder binder, int mode, String[] input, int outputSize)
            throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        try {
            data.writeInterfaceToken(SETTINGS_INTERFACE);
            data.writeInt(mode);
            data.writeStringArray(input);
            data.writeInt(outputSize);
            binder.transact(TRANSACTION_DTS_TYPE, data, reply, 0);
            reply.readException();
            int resultCode = reply.readInt();
            String[] output = new String[outputSize];
            reply.readStringArray(output);
            return new DtsResult(resultCode, output);
        } finally {
            reply.recycle();
            data.recycle();
        }
    }

    private void completeOnMain(Outcome outcome) {
        mainHandler.post(() -> {
            if (bound) {
                context.unbindService(connection);
                bound = false;
            }
            executor.shutdown();
            callback.onComplete(outcome);
        });
    }

    static final class Outcome {
        final boolean success;
        final String message;

        private Outcome(boolean success, String message) {
            this.success = success;
            this.message = message;
        }

        static Outcome success(String message) {
            return new Outcome(true, message);
        }

        static Outcome failure(String message) {
            return new Outcome(false, message);
        }
    }

    private static final class DtsResult {
        final int code;
        final String[] output;

        DtsResult(int code, String[] output) {
            this.code = code;
            this.output = output;
        }

        String valueAt(int index) {
            return index < output.length ? output[index] : null;
        }
    }
}