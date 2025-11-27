# PHP 8.4 SPK Package for Synology NAS

A complete PHP 8.4.15 package for Synology DSM 7.2+ with Extension Manager and 100+ extensions.

## Features

- **PHP 8.4.15** - Latest PHP version with all modern features
- **PHP-FPM** - FastCGI Process Manager for high-performance web serving
- **Extension Manager** - DSM native UI for enabling/disabling extensions
- **100+ Extensions** - Comprehensive set of PHP extensions organized by category
- **DSM 7.2+ Compatible** - Built for modern Synology systems

## Supported Architecture

| Architecture | DSM Version | Status |
|--------------|-------------|--------|
| Geminilake (DS920+, DS720+, etc.) | 7.2+ | Supported |

## Included Extensions

### Core Extensions (51 shared)
bcmath, bz2, calendar, ctype, curl, dba, dom, exif, ffi, fileinfo, filter, ftp, gd, gettext, gmp, iconv, intl, ldap, mbstring, mysqli, mysqlnd, odbc, opcache, openssl, pcntl, pdo, pdo_mysql, pdo_odbc, pdo_sqlite, phar, posix, readline, session, shmop, simplexml, snmp, soap, sockets, sodium, sqlite3, sysvmsg, sysvsem, sysvshm, tidy, tokenizer, xml, xmlreader, xmlwriter, xsl, zip, zlib

### PECL Extensions (~50)
amqp, apcu, ast, ds, event, ev, igbinary, imagick, memcached, mongodb, msgpack, oauth, redis, ssh2, swoole, uuid, xdebug, yaml, and many more...

## Installation

### From Package Center
1. Download the `.spk` file from [Releases](https://github.com/Kalletal/php84/releases)
2. Open Package Center in DSM
3. Click "Manual Install"
4. Select the `.spk` file
5. Follow the installation wizard

### Installation Profiles
During installation, choose your profile:

| Profile | Description | Extensions |
|---------|-------------|------------|
| **Minimal** | Essential extensions only | ~10 extensions |
| **Standard** | Common web app extensions | ~30 extensions |
| **Complete** | All available extensions | 100+ extensions |

## Usage

### PHP CLI
```bash
# Direct path
/var/packages/php84/target/bin/php -v

# With library path
LD_LIBRARY_PATH="/var/packages/php84/target/lib" /var/packages/php84/target/bin/php -v
```

### PHP-FPM Socket
```
/var/packages/php84/var/run/php-fpm.sock
```

### Configuration Files
| File | Location |
|------|----------|
| php.ini | `/var/packages/php84/var/etc/php.ini` |
| php-fpm.conf | `/var/packages/php84/var/etc/php-fpm.conf` |
| Pool config | `/var/packages/php84/var/etc/php-fpm.d/www.conf` |
| Extension configs | `/var/packages/php84/var/etc/conf.d/*.ini` |

### Extension Manager
Access via DSM Menu > PHP 8.4 Extension Manager

## Building from Source

### Prerequisites
- Linux build system (Ubuntu/Debian recommended)
- [spksrc](https://github.com/SynoCommunity/spksrc) framework
- Cross-compilation toolchain for target architecture

### Build Steps
```bash
# Clone repository
git clone https://github.com/Kalletal/php84.git
cd php84

# Build SPK
cd spk/php84
./scripts/build-spk.sh

# With version bump
./scripts/build-spk.sh --bump
```

### Output
```
dist/php84-8.4.15-XXXX-geminilake-7.2.spk
```

## Troubleshooting

### Package won't start
Run the cleanup script:
```bash
sudo sh /path/to/cleanup-nas.sh
sudo synopkg restart php84
```

### Extension not loading
1. Check if the `.so` file exists in `/var/packages/php84/target/lib/php/extensions/`
2. Verify the `.ini` file exists in `/var/packages/php84/var/etc/conf.d/`
3. Check PHP error log: `/var/packages/php84/var/log/php_errors.log`

### PHP-FPM configuration test
```bash
LD_LIBRARY_PATH="/var/packages/php84/target/lib" \
  /var/packages/php84/target/sbin/php-fpm -t \
  -c /var/packages/php84/var/etc/php.ini \
  -y /var/packages/php84/var/etc/php-fpm.conf
```

## Project Structure

```
php84/
├── spk/php84/              # SPK package source
│   ├── src/
│   │   ├── scripts/        # postinst, preuninst, start-stop-status
│   │   ├── ui/             # DSM Extension Manager UI
│   │   ├── wizard/         # Installation wizard
│   │   ├── conf/           # Package configuration
│   │   └── target/         # PHP binaries and libraries
│   ├── scripts/            # Build scripts
│   └── dist/               # Built SPK packages
└── spksrc/                 # spksrc framework (submodule)
```

## License

- PHP: [PHP License 3.01](https://www.php.net/license/3_01.txt)
- This package: MIT License

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Credits

- [PHP Group](https://www.php.net/) - PHP language
- [SynoCommunity](https://synocommunity.com/) - spksrc framework
- Contributors and testers

## Changelog

### 8.4.15-0015
- Fixed duplicate .ini files issue (extensions loaded twice)
- Added libmemcached.so.11 for memcached extension support
- Improved Extension Manager with proper load order prefixes
- Added cleanup script for existing installations

### 8.4.15-0014
- Initial release with Extension Manager
- 100+ PHP extensions
- DSM 7.2+ native UI integration
