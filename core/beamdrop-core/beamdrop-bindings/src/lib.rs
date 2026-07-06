#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BindingTarget {
    Kotlin,
    Swift,
    CSharp,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BindingStatus {
    Planned,
    Generated,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BindingPlan {
    pub target: BindingTarget,
    pub status: BindingStatus,
    pub crate_boundary: &'static str,
    pub generation_strategy: &'static str,
    pub notes: &'static str,
}

pub fn binding_plans() -> Vec<BindingPlan> {
    vec![
        BindingPlan {
            target: BindingTarget::Kotlin,
            status: BindingStatus::Planned,
            crate_boundary: "beamdrop-bindings",
            generation_strategy: "UniFFI or JNI facade after protocol/core APIs stabilize",
            notes: "Android bindings must expose safe models and async transfer handles, not raw private keys.",
        },
        BindingPlan {
            target: BindingTarget::Swift,
            status: BindingStatus::Planned,
            crate_boundary: "beamdrop-bindings",
            generation_strategy: "UniFFI-generated Swift module after FFI-safe API design",
            notes: "iOS and macOS bindings must preserve platform clipboard and background limitations.",
        },
        BindingPlan {
            target: BindingTarget::CSharp,
            status: BindingStatus::Planned,
            crate_boundary: "beamdrop-bindings",
            generation_strategy: "C ABI plus C# P/Invoke or CsWinRT-compatible wrapper",
            notes: "Windows bindings must expose WinUI-friendly async operations and avoid blocking UI threads.",
        },
    ]
}

pub fn bindings_are_generated() -> bool {
    binding_plans()
        .iter()
        .all(|plan| plan.status == BindingStatus::Generated)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn documents_all_native_binding_targets() {
        let plans = binding_plans();

        assert_eq!(plans.len(), 3);
        assert!(plans.iter().any(|plan| plan.target == BindingTarget::Kotlin));
        assert!(plans.iter().any(|plan| plan.target == BindingTarget::Swift));
        assert!(plans.iter().any(|plan| plan.target == BindingTarget::CSharp));
        assert!(!bindings_are_generated());
    }
}
