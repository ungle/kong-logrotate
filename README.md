# Kong-logrortate

Inner plugin to finish logrotate process in kong, without requiring external configuration files.
Rotated file will be renamed as *original-name-%Y%m%d%H%M%S*

**Still under development**


## Configuration
Only global plugin mode is allowed

- rotate_interval: integer, must be greater than 0, default is 1.
- rotate_interval_unit: time unit of *rotate_interval*, must be string, must be one of *minute*, *hour*, *day*, *month* or *year*, default is *day*.
- log_paths: set, elements must be string, default are */usr/local/kong/logs/access.log*, */usr/local/kong/logs/error.log* and */usr/local/kong/logs/admin_access.log*.
- max_kept: max number of files that can be kept with same name prefix (e.g. access.log and access.log-202203072359), must be greater than 0, default is 1.
- max_size: max file size of log files in bytes, if the size is bigger than this limit, rotation will be triggered. Must be greater than 0, default is 104857600 (100MB).
- compression: define whether the rotated file needs to be compressed, must be boolean, default is false.

