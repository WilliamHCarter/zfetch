<div align="center">
  <img src="readme-header.svg" width="400" height="100" alt="zfetch">
</div>
<p align="center">A command-line system information tool written in Zig</p>
<div align="center">
<a href="./LICENSE.md"><img src="https://img.shields.io/badge/license-MIT-blue.svg"></a>
<img alt="GitHub top language" src="https://img.shields.io/github/languages/top/williamhcarter/zfetch?logo=Zig&label=%20">
</div>
<img height="16px">



ZFetch is a lighweight command-line system information tool written in Zig, with an emphasis on simplicity and light customization. It offers cross-platform support MacOS, Linux and Windows, and is designed to be easy to modify and tinker with.

## Features

- Fast and lightweight system information display
- Written in Zig for high performance and readable code
- Customizable output via theme files
- Cross-platform support (Linux, macOS, Windows)

## Installation

### Homebrew
To install ZFetch using the Homebrew package manager, you'll need to have homebrew installed.

Run the following commands in your terminal:
```
brew tap WilliamHCarter/zfetch
brew install zfetch
```

### Build from Source
To build ZFetch from source, you'll need to have Zig installed on your system. Follow these steps:

Clone the repository:
```
git clone https://github.com/williamhcarter/zfetch.git
cd zfetch
```

Build the project:

```
zig build
```

The compiled binary will be available in the zig-out/bin directory.

### Download Binary
You can download pre-compiled binaries for your platform from the Releases page. Choose the appropriate version for your operating system and architecture.
