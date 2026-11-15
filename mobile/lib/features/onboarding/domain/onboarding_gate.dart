/// Onboarding order (Constitution II + III): health disclaimer → consent → quiz → plan.
/// Pure so the rules are unit-tested without a router.
library;

/// Version of the consent text in `consentBody`. Bump it when the text changes; users who
/// accepted an older version are asked again (T044).
const kConsentVersion = '2026-11-v1';

/// Where to send the user instead of [location], or null to allow it.
String? onboardingRedirect({
  required String location,
  required bool disclaimerAccepted,
  required bool consentGiven,
  bool planGenerated = false,
}) {
  // The trial offer follows plan generation in this session only; it is never shown again on
  // a later app open (FR-004).
  if (location == '/onboarding/trial' && !planGenerated) return '/home';

  final needsDisclaimer = location == '/onboarding/consent' ||
      location.startsWith('/onboarding/quiz') ||
      location.startsWith('/onboarding/generating');
  if (needsDisclaimer && !disclaimerAccepted) return '/onboarding/disclaimer';

  final needsConsent = location.startsWith('/onboarding/quiz') || location.startsWith('/onboarding/generating');
  if (needsConsent && !consentGiven) return '/onboarding/consent';
  return null;
}

/// Where to send a signed-out user instead of [location], or null to allow it. The welcome
/// screen is the only onboarding screen before sign-in (spec US1 order, FR-043).
String? signedOutRedirect(String location) =>
    location == '/onboarding/welcome' || location == '/auth' ? null : '/onboarding/welcome';

/// True when the user accepted a consent text older than the current one.
bool needsReconsent(String? acceptedVersion) => acceptedVersion != null && acceptedVersion != kConsentVersion;
