# Real-device checks

After each passed build, install the unsigned IPA using LiveContainer or your signing tool and check:

- Cloudflare sign-in including 2FA, app relaunch and expired-session recovery.
- Safe areas and keyboard dismissal on the actual phone.
- Glance swipe release logs exactly one watch and preserves scroll position; Undo restores it.
- Home carousel and Library scroll smoothness with a large library.
- Remaining-time contrast over bright art and Liquid Glass readability.
- Native menu presentation, tap highlight release and theme switching.
- Haptics and animation timing require physical-device evaluation and are not established by CI screenshots.

Hosted mutation tests require the owner's explicit authorization. Simulator checks use synthetic fixtures.
