# AIDM — Repository access and checkout

**Story:** AIDM-DES-026.1  
**Owner:** COSTA  
**Date:** 2026-11-17

Repository (private): `https://github.com/glade90/aidm`.

Clone with a GitHub account authorised to access the private repository:

```sh
git clone https://github.com/glade90/aidm.git
cd aidm
git fetch origin
git switch costa  # or davos / ester for assigned developer
```

The branch names refer to **working roles**, not automatically provisioned GitHub identities. Any additional human GitHub collaborators must be granted access separately by the repository owner. Never share GitHub access tokens in source code, prompts or Story records.

Normal change integration: make and test a coherent change on your persistent branch, push it, and open a PR into `main` with its Airtable JiraID and verification evidence. After an accepted squash merge, reset/synchronise your own persistent branch to the accepted `main` tip **only when no unmerged work would be lost**. BON coordinates any conflicting work. CI and branch protections are governed separately by AIDM-DES-027.

**Change Log:** 2026-11-17 COSTA — Initial repository access instructions for PR-workflow demonstration.
