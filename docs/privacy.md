# Privacy Policy - LiveVoice Box

Last updated: June 14, 2026

Effective date: `[EFFECTIVE_DATE]`

Developer/operator: `[OPERATOR_NAME]`

Privacy contact: zeb0kui3ackwv4pft1us@gmail.com

Privacy Policy URL: https://taichi963.github.io/tikbox/privacy.html

Support URL: https://taichi963.github.io/tikbox/support.html

The developer/operator name and effective date must be completed before this
policy is submitted to an app store.

[Privacy Policy](privacy.html) | [Terms of Use](terms.html) |
[Support](support.html) |
[GitHub Repository](https://github.com/Taichi963/tikbox)

## About The App

LiveVoice Box is an unofficial live-stream support tool. It is not affiliated
with, endorsed by, or sponsored by TikTok, ByteDance, or any other
live-streaming platform.

## Information Used By The App

LiveVoice Box uses the following information to provide its features:

- Stream ID entered by the user: used to connect to the selected public LIVE.
- Public live comments and public user display names: used for on-screen
  display and text-to-speech playback.
- Public gift events: used for gift display, sound, vibration, and
  text-to-speech feedback.
- App settings: used to restore speech, sound, vibration, and display
  preferences.
- Stream ID history: used to show recently entered stream IDs.

Live comments and gift events are kept in app memory while the app is running.
The app does not write comment text or gift-event history to SharedPreferences
or to a LiveVoice Box-operated database.

## Information Not Collected By LiveVoice Box

The app does not ask for or collect:

- TikTok account passwords or other login credentials
- existing browser cookies, login cookies, or authenticated app session cookies
- private messages
- payment or financial information
- contacts, photos, precise location, or microphone recordings

The app does not include a WebView login or a mechanism for extracting account
cookies from the user's browser or TikTok app.

The bundled LIVE connection library makes an unauthenticated request to TikTok
and receives a service-issued `ttwid` cookie for the public WebSocket
connection. This cookie is not a user login credential, is not read from the
user's browser or TikTok app, and is not saved by LiveVoice Box in
SharedPreferences or an app database.

## Local Device Storage

LiveVoice Box uses Flutter SharedPreferences to store the following information
on the user's device:

- text-to-speech, sound, vibration, and display settings
- the most recently entered stream ID
- saved stream ID history
- user-added blocked words
- blocked public LIVE user IDs

This information is not uploaded to a LiveVoice Box-operated server.

If a public LIVE user ID is unavailable, a display-name block applies only to
the current connection session and is not saved.

## Network Communication And Third-Party Services

- The app sends connection requests based on the entered stream ID to the
  public LIVE service.
- The bundled LIVE connection library obtains and returns a service-issued
  `ttwid` cookie as part of establishing the public LIVE connection.
- Public live comments, public user display names, and public gift events are
  received through the live connection and processed by the app.
- Text-to-speech is performed through the text-to-speech service configured on
  the device. The selected operating-system or TTS provider may apply its own
  privacy terms.
- The current app does not include a LiveVoice Box-operated backend, advertising
  SDK, analytics SDK, account system, or external cloud TTS service.
- The comment report screen prepares a report containing the selected public
  display name, public LIVE user reference, comment text, time, and report
  reason. The app also includes the published support email and report subject
  in the copied text. The user sends the report from their email app; LiveVoice
  Box does not automatically transmit it.
- The prepared report does not include cookies, `ttwid`, a device ID, complete
  internal logs, login credentials, or authentication information.

TikTok and ByteDance operate independently from LiveVoice Box. Their processing
of requests and public LIVE data is governed by their own terms and privacy
policies.

## Diagnostic Logs

The app writes diagnostic messages to the operating system log to help
troubleshoot connection, background-audio, gift, and vibration behavior. These
messages may include:

- the entered stream ID
- public user display names
- gift names, counts, and public gift values
- connection and audio state information

LiveVoice Box does not upload these diagnostic logs to a LiveVoice Box-operated
server. Log availability and retention are controlled by the operating system
and device tools.

## Retention And Deletion

- Settings remain on the device until they are changed, the app's storage is
  cleared, or the app is uninstalled.
- Saved stream IDs remain on the device until the user removes them in the app,
  clears the app's storage, or uninstalls the app.
- User-added blocked words and blocked public LIVE user IDs remain on the device
  until the user removes them, clears the app's storage, or uninstalls the app.
- Live comments and gift events held in memory are not retained after the app
  process ends.
- LiveVoice Box does not operate an account or server-side user database, so
  there is no server account data to delete.

Users can delete an individual saved stream ID from the saved-ID list. To
remove all locally stored settings and history, users can clear the app's
storage through the operating-system settings or uninstall the app.

## Children

LiveVoice Box is not designed specifically for children. The app does not ask
for a date of birth or age. Users must follow the age and account requirements
of the live-streaming platform and the app store through which they obtained
the app.

## Security

Settings and stream ID history are stored within the app's local storage area
using SharedPreferences. Protection of this local data depends on the device
and operating-system security controls. No method of storage or transmission
can be guaranteed to be completely secure.

## Policy Updates

This policy must be updated before release if the app's data practices change,
including the addition of analytics, advertising, a backend server, external
cloud TTS, or account features. Material updates should include a revised
"Last updated" date.

## Contact

Privacy inquiries and comment reports:
zeb0kui3ackwv4pft1us@gmail.com

For support instructions, see the [Support page](support.html).
