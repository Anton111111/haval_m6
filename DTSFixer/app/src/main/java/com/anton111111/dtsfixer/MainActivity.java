package com.anton111111.dtsfixer;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        Spinner modeSpinner = findViewById(R.id.mode_spinner);
        TextView modeDescription = findViewById(R.id.mode_description);
        CheckBox silentMode = findViewById(R.id.silent_mode_checkbox);
        EditText delayInput = findViewById(R.id.delay_seconds_input);
        Button saveButton = findViewById(R.id.save_button);
        Button testButton = findViewById(R.id.test_mode_button);

        SharedPreferences preferences = BootSettings.preferences(this);
        BootSettings.Mode mode = BootSettings.Mode.fromValue(
                preferences.getString(BootSettings.KEY_MODE, BootSettings.Mode.RESET_DTS.value));
        String[] modeTitles = {
                getString(R.string.mode_reset_dts_title),
                getString(R.string.mode_theatre_full_car_title)
        };
        ArrayAdapter<String> modeAdapter = new ArrayAdapter<>(
            this, R.layout.item_mode_spinner, modeTitles);
        modeAdapter.setDropDownViewResource(R.layout.item_mode_spinner_dropdown);
        modeSpinner.setAdapter(modeAdapter);
        modeSpinner.setSelection(mode == BootSettings.Mode.RESET_DTS ? 0 : 1);
        updateModeDescription(modeDescription, modeSpinner.getSelectedItemPosition());
        modeSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                updateModeDescription(modeDescription, position);
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        silentMode.setChecked(preferences.getBoolean(BootSettings.KEY_SILENT, false));
        delayInput.setText(String.valueOf(BootSettings.delaySeconds(preferences)));

        saveButton.setOnClickListener(view -> {
            BootSettings.Mode selectedMode = modeSpinner.getSelectedItemPosition() == 1
                    ? BootSettings.Mode.THEATRE_FULL_CAR
                    : BootSettings.Mode.RESET_DTS;
            int delaySeconds = parseDelay(delayInput.getText().toString());
            delayInput.setText(String.valueOf(delaySeconds));

            preferences.edit()
                    .putString(BootSettings.KEY_MODE, selectedMode.value)
                    .putBoolean(BootSettings.KEY_SILENT, silentMode.isChecked())
                    .putInt(BootSettings.KEY_DELAY_SECONDS, delaySeconds)
                    .apply();
            Toast.makeText(this, R.string.settings_saved, Toast.LENGTH_SHORT).show();
        });

        testButton.setOnClickListener(view -> {
            BootSettings.Mode selectedMode = modeSpinner.getSelectedItemPosition() == 1
                    ? BootSettings.Mode.THEATRE_FULL_CAR
                    : BootSettings.Mode.RESET_DTS;
            testButton.setEnabled(false);
            Toast.makeText(this, R.string.test_started, Toast.LENGTH_SHORT).show();
            DtsController.run(this, selectedMode, outcome -> {
                testButton.setEnabled(true);
                Toast.makeText(this, outcome.message, Toast.LENGTH_LONG).show();
            });
        });
    }

    private void updateModeDescription(TextView description, int position) {
        description.setText(position == 1
                ? R.string.mode_theatre_full_car_description
                : R.string.mode_reset_dts_description);
    }

    private int parseDelay(String value) {
        try {
            return BootSettings.sanitizeDelay(Integer.parseInt(value));
        } catch (NumberFormatException exception) {
            return BootSettings.DEFAULT_DELAY_SECONDS;
        }
    }
}