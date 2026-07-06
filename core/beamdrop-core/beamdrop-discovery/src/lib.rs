use beamdrop_protocol::{DeviceAdvertisement, Validate};
use std::error::Error;
use std::fmt;

pub const SERVICE_NAME: &str = "_beamdrop._tcp";
pub const TXT_PROTOCOL_VERSION_KEY: &str = "protocolVersion";
pub const TXT_DEVICE_ID_KEY: &str = "deviceId";
pub const TXT_DEVICE_NAME_KEY: &str = "deviceName";
pub const TXT_PLATFORM_KEY: &str = "platform";
pub const TXT_PUBLIC_KEY_KEY: &str = "publicKey";
pub const TXT_FEATURES_KEY: &str = "features";

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiscoveryRecord {
    pub service_name: String,
    pub host: String,
    pub port: u16,
    pub advertisement: DeviceAdvertisement,
}

impl DiscoveryRecord {
    pub fn new(
        service_name: impl Into<String>,
        host: impl Into<String>,
        port: u16,
        advertisement: DeviceAdvertisement,
    ) -> Result<Self, DiscoveryError> {
        let record = Self {
            service_name: service_name.into(),
            host: host.into(),
            port,
            advertisement,
        };
        record.validate()?;
        Ok(record)
    }

    pub fn validate(&self) -> Result<(), DiscoveryError> {
        if self.service_name != SERVICE_NAME {
            return Err(DiscoveryError::InvalidServiceName(self.service_name.clone()));
        }
        if self.host.trim().is_empty() {
            return Err(DiscoveryError::MissingHost);
        }
        if self.port == 0 {
            return Err(DiscoveryError::InvalidPort);
        }
        self.advertisement.validate().map_err(|error| {
            DiscoveryError::InvalidAdvertisement(error.to_string())
        })?;
        Ok(())
    }
}

pub trait DiscoveryProvider {
    fn start(&mut self) -> Result<(), DiscoveryError>;
    fn stop(&mut self) -> Result<(), DiscoveryError>;
    fn publish(&mut self, advertisement: DeviceAdvertisement) -> Result<(), DiscoveryError>;
    fn discovered_records(&self) -> Result<Vec<DiscoveryRecord>, DiscoveryError>;
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DiscoveryError {
    InvalidServiceName(String),
    MissingHost,
    InvalidPort,
    InvalidAdvertisement(String),
    ProviderUnavailable,
}

impl fmt::Display for DiscoveryError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidServiceName(service_name) => {
                write!(f, "invalid discovery service name: {service_name}")
            }
            Self::MissingHost => write!(f, "discovery host must not be empty"),
            Self::InvalidPort => write!(f, "discovery port must be non-zero"),
            Self::InvalidAdvertisement(message) => write!(f, "invalid advertisement: {message}"),
            Self::ProviderUnavailable => write!(f, "discovery provider is unavailable"),
        }
    }
}

impl Error for DiscoveryError {}

#[cfg(test)]
mod tests {
    use super::*;
    use beamdrop_protocol::{Platform, TransferType, PROTOCOL_VERSION};

    #[test]
    fn builds_valid_discovery_record() {
        let advertisement = DeviceAdvertisement {
            protocol_version: PROTOCOL_VERSION.to_owned(),
            service_name: Some(SERVICE_NAME.to_owned()),
            device_id: "bd-macos-01J2M8Q8RXE4KZ9G7V1N0Q4F2A".to_owned(),
            device_name: "Will's MacBook Pro".to_owned(),
            platform: Platform::Macos,
            public_key: "MCowBQYDK2VuAyEAtqzFJY2dveH2WrN9q9NqbcMTFq0QnV8DScjQ7kSy3xY=".to_owned(),
            features: vec![TransferType::Text, TransferType::File],
            port: 49320,
        };

        let record = DiscoveryRecord::new(SERVICE_NAME, "192.168.1.42", 49320, advertisement);
        assert!(record.is_ok());
    }
}
