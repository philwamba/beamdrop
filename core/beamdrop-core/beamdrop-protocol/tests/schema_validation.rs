//! Semantic JSON Schema validation of the protocol contract.
//!
//! Runs in CI via `cargo test --workspace` with no network access: schemas and
//! examples are read from the repository, and the validator is a pinned crate
//! dependency. Every example must validate against its schema, and every
//! schema must itself compile as JSON Schema draft 2020-12.

use std::fs;
use std::path::{Path, PathBuf};

fn protocol_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../protocol/beamdrop-protocol")
}

fn load_json(path: &Path) -> serde_json::Value {
    let raw = fs::read_to_string(path)
        .unwrap_or_else(|error| panic!("failed to read {}: {error}", path.display()));
    serde_json::from_str(&raw)
        .unwrap_or_else(|error| panic!("{} is not valid JSON: {error}", path.display()))
}

fn compiled_schema(name: &str) -> jsonschema::Validator {
    let path = protocol_dir().join("schemas").join(name);
    let schema = load_json(&path);
    jsonschema::validator_for(&schema)
        .unwrap_or_else(|error| panic!("{name} failed to compile: {error}"))
}

fn assert_example_valid(schema_name: &str, example_name: &str) {
    let validator = compiled_schema(schema_name);
    let example_path = protocol_dir().join("examples").join(example_name);
    let example = load_json(&example_path);

    let errors: Vec<String> = validator
        .iter_errors(&example)
        .map(|error| format!("{} at {}", error, error.instance_path()))
        .collect();
    assert!(
        errors.is_empty(),
        "{example_name} does not satisfy {schema_name}:\n{}",
        errors.join("\n")
    );
}

#[test]
fn all_schemas_compile() {
    let schemas_dir = protocol_dir().join("schemas");
    let mut count = 0;
    for entry in fs::read_dir(&schemas_dir).expect("schemas directory") {
        let path = entry.expect("directory entry").path();
        if path.extension().is_some_and(|ext| ext == "json") {
            let schema = load_json(&path);
            jsonschema::validator_for(&schema).unwrap_or_else(|error| {
                panic!("{} failed to compile: {error}", path.display())
            });
            count += 1;
        }
    }
    assert!(count >= 7, "expected at least 7 schemas, found {count}");
}

#[test]
fn device_advertisement_example_matches_schema() {
    assert_example_valid(
        "device-advertisement.schema.json",
        "device-advertisement.example.json",
    );
}

#[test]
fn pairing_request_example_matches_schema() {
    assert_example_valid("pairing-request.schema.json", "pairing-request.example.json");
}

#[test]
fn pairing_response_example_matches_schema() {
    assert_example_valid(
        "pairing-response.schema.json",
        "pairing-response.example.json",
    );
}

#[test]
fn text_transfer_example_matches_transfer_envelope_schema() {
    assert_example_valid("transfer-envelope.schema.json", "text-transfer.example.json");
}

#[test]
fn file_transfer_example_matches_transfer_envelope_schema() {
    assert_example_valid("transfer-envelope.schema.json", "file-transfer.example.json");
}

#[test]
fn transfer_progress_example_matches_schema() {
    assert_example_valid(
        "transfer-progress.schema.json",
        "transfer-progress.example.json",
    );
}

#[test]
fn transfer_result_example_matches_schema() {
    assert_example_valid("transfer-result.schema.json", "transfer-result.example.json");
}

#[test]
fn schema_rejects_invalid_envelope() {
    let validator = compiled_schema("transfer-envelope.schema.json");
    let mut example = load_json(
        &protocol_dir()
            .join("examples")
            .join("file-transfer.example.json"),
    );

    example["transferType"] = serde_json::json!("NOT_A_REAL_TYPE");
    assert!(
        !validator.is_valid(&example),
        "schema accepted an invalid transferType — semantic validation is not effective"
    );

    example
        .as_object_mut()
        .expect("object")
        .remove("transferId");
    assert!(
        !validator.is_valid(&example),
        "schema accepted an envelope with no transferId"
    );
}
