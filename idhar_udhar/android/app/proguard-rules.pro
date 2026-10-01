# Customer release startup calls these by name from MainActivity.
# R8 otherwise renames the class and deletes register(), and
# Class.getDeclaredMethod throws NoSuchMethodException inside Activity.onCreate.
-keep class com.idharudhar.idhar_udhar.OtpAutofillInstaller {
    public static void register(io.flutter.embedding.engine.FlutterEngine, io.flutter.embedding.android.FlutterActivity);
    public static boolean handleActivityResult(int, int, android.content.Intent);
}

# SMS User Consent client used only after the customer asks for an OTP.
# Keep the entry points the installer calls. Do not request READ_SMS.
-keep class com.google.android.gms.auth.api.phone.SmsRetriever { *; }
-keep class com.google.android.gms.auth.api.phone.SmsRetrieverClient { *; }
