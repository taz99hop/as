CREATE TABLE IF NOT EXISTS `parcel_express_stats` (
  `citizenid` VARCHAR(60) NOT NULL,
  `total_delivered` INT NOT NULL DEFAULT 0,
  `total_earnings` INT NOT NULL DEFAULT 0,
  `rating` DECIMAL(4,2) NOT NULL DEFAULT 5.00,
  `level` INT NOT NULL DEFAULT 1,
  `level_title` VARCHAR(40) NOT NULL DEFAULT 'مبتدئ',
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `parcel_express_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(60) NOT NULL,
  `route_id` INT NOT NULL,
  `payout` INT NOT NULL,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_parcel_citizenid` (`citizenid`),
  INDEX `idx_parcel_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
