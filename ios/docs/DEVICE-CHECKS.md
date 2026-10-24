# Real-device checks

After each passed build, install the unsigned IPA using LiveContainer or your signing tool and check:

- Cloudflare sign-in including 2FA, app relaunch and expired-session recovery.
- Safe areas and keyboard dismissal on the actual phone.
- Glance swipe release logs exactly one watch and preserves scroll position; Undo restores it.
- Home carousel and Library scroll smoothness with a large library.
- Remaining-time contrast over bright art and Liquid Glass readability.
- Native menu presentation, tap highlight release and theme switching.
- Haptics and animation timing require physical-device evaluation and are not established by CI screenshots.
- Trakt auth-only browser: direct sign-in, server callback, expired Access session and cancellation. For identity providers that reject embedded browsers, use Connect in browser and confirm that returning to the app refreshes the connection.
- Cold-launch the saved diary with networking unavailable, then reconnect. Confirm the saved-copy notice and the server refresh, and verify that signing out removes the cached diary.
- Drag a series track across several episode counts, change seasons quickly, log a past-date movie rewatch, and Undo while the content stays in place. Simulator pixels and mock transport coverage do not prove physical gesture timing.

Hosted mutation tests require the owner's explicit authorization. Simulator checks use synthetic fixtures.

- Random pick: three logo taps within 850ms open one dialog; ordinary spaced taps only spin the logo. Check the 650ms reroll guard, reduced-motion behavior, VoiceOver modal focus/escape and keyboard dismissal. CI screenshots cannot establish those physical timings.
