use dep::aztec::{
    context::PrivateContext,
    keys::getters::{get_nsk_app, get_public_keys},
    macros::notes::note,
    note::{note_header::NoteHeader, note_interface::NullifiableNote, utils::compute_note_hash_for_nullify},
    oracle::random::random,
    protocol_types::{
        address::AztecAddress,
        constants::GENERATOR_INDEX__NOTE_NULLIFIER,
        hash::poseidon2_hash_with_separator,
    },
};

// Note sent back from verifier to shooter with result
#[note]
pub struct ResultNote {
    game_id: Field,
    x: u8,
    y: u8,
    is_hit: bool,
    from: AztecAddress,
    randomness: Field,
}

impl NullifiableNote for ResultNote {
    fn compute_nullifier(
        self,
        context: &mut PrivateContext,
        note_hash_for_nullify: Field,
    ) -> Field {
        let from_npk_m_hash: Field = get_public_keys(self.from).npk_m.hash();
        let secret = context.request_nsk_app(from_npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }

    unconstrained fn compute_nullifier_without_context(self) -> Field {
        let note_hash_for_nullify = compute_note_hash_for_nullify(self);
        let from_npk_m_hash: Field = get_public_keys(self.from).npk_m.hash();
        let secret = get_nsk_app(from_npk_m_hash);
        poseidon2_hash_with_separator(
            [note_hash_for_nullify, secret],
            GENERATOR_INDEX__NOTE_NULLIFIER as Field,
        )
    }
}

impl ResultNote {
    pub fn new(game_id: Field, x: u8, y: u8, is_hit: bool, from: AztecAddress) -> Self {
        let randomness = unsafe { random() };
        let header = NoteHeader::empty();
        ResultNote {
            game_id,
            x,
            y,
            is_hit,
            from,
            randomness,
            header,
        }
    }
}
