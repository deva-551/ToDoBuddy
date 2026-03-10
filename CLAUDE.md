# ToDoBuddy - Project Guidelines

## Pre-Push Security Checklist

Before pushing to a public repository, ALWAYS validate:

1. **No personal email addresses** in commits, source files, or config files
   - Allowed email: `mistrotheone@gmail.com`
   - Corporate/work emails must NEVER be committed
2. **No Apple Development Team IDs** in `project.pbxproj` — `DEVELOPMENT_TEAM` must be `""`
3. **No API keys, tokens, or secrets** in any source file
4. **No hardcoded personal file paths** (e.g., `/Users/<username>/...`) in committed files
5. **`.gitignore`** must exclude: `xcuserdata/`, `DerivedData/`, `.DS_Store`, `.claude/`

## Git Author Config

- Email: `mistrotheone@gmail.com`
- Never use corporate/work email addresses in commits
