# Claude Desktop

En macOS-app som lar Claude ta kontroll over mus og tastatur via Anthropic's Computer Use API.

## Bygg

```bash
# Åpne i Xcode
open Package.swift

# Eller bygg fra terminal
swift build
```

## Oppsett

1. **Bygg og kjør appen i Xcode**
2. **Gi tillatelser:**
   - System Settings → Privacy & Security → Screen Recording → Legg til Claude Desktop
   - System Settings → Privacy & Security → Accessibility → Legg til Claude Desktop
3. **Legg inn API-nøkkel** i Innstillinger (tannhjul-ikon)

## Bruk

- Chat med Claude som vanlig
- Aktiver "Computer Use" toggle for å la Claude kontrollere mus/tastatur
- Claude kan ta screenshots, klikke, skrive tekst, etc.

## Krav

- macOS 13.0+
- Xcode 15+
- Anthropic API-nøkkel
