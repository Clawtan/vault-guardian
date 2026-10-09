# ðŸ›¡ï¸ Vault Guardian

[![Ecosystem: Obsidian](https://img.shields.io/badge/Obsidian-Second%20Brain-purple.svg)](https://obsidian.md/)
[![Language: PowerShell](https://img.shields.io/badge/Language-PowerShell-blue.svg)](https://microsoft.com/powershell)
[![Static Engine: Quartz](https://img.shields.io/badge/Quartz-SSG%20Ready-orange.svg)](https://quartz.jzhao.xyz/)
[![Performance: O(1) HashSet](https://img.shields.io/badge/Scan%20Speed-O(1)%20HashSet%20%7E3s-success.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

High-speed graph integrity guardian, wikilink validator, and cloud sync clutter eliminator for large-scale Obsidian vaults (3,800+ markdown notes).

---

## âš¡ Features

- **Sub-Second O(1) HashSet Scanner**: Validates wikilink references, aliases, and filenames across 3,800+ notes in under 3 seconds.
- **Zero-Orphan Policy**: Detects and highlights notes without incoming backlinks to ensure complete Map of Content (MOC) graph connectivity.
- **Cloud Sync Conflict Cleaner**: Detects and purges sync clash files from Proton Drive, iCloud, and Dropbox (\*(# Edit conflict*\, \*.bak\, \*.tmp\).
- **Quartz SSG Slugification Compliance**: Ensures markdown notes follow clean static site generator naming standards.

---

## ðŸ“œ License

MIT License. Built by [Clawtan](https://github.com/Clawtan).
