"""Focused checks for the triage contract and safety rules."""

import tempfile
import unittest
from pathlib import Path

from triage import (
    AUTO_ANSWERS,
    Decision,
    Message,
    apply_safety_rules,
    read_messages,
    summarize,
)


def message(text: str = "¿Cómo pago por PSE?") -> Message:
    return Message.model_validate(
        {
            "id": "MSG-TEST",
            "channel": "chat",
            "received_at": "2026-05-04T08:00:00",
            "from": "cliente_1",
            "text": text,
        }
    )


def decision(**changes) -> Decision:
    data = {
        "main_reason": "metodos_de_pago",
        "secondary_intents": [],
        "priority": "baja",
        "entities": {
            "document_numbers": [],
            "credit_ids": [],
            "amounts": [],
            "dates": [],
            "references": [],
        },
        "action": "responder_automaticamente",
        "queue": None,
        "draft_reply": "Puedes pagar por PSE desde la app.",
        "policy_refs": ["pagos_y_cuotas.md#metodos-de-pago"],
    }
    data.update(changes)
    return Decision.model_validate(data)


class TriageTests(unittest.TestCase):
    def test_input_rejects_bad_json_and_duplicate_ids(self):
        record = message().model_dump_json(by_alias=True)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "messages.jsonl"
            path.write_text("not json\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "line 1"):
                read_messages(path)

            path.write_text(f"{record}\n{record}\n", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "duplicate message id"):
                read_messages(path)

    def test_human_reason_overrides_model_and_fraud_wins(self):
        result = apply_safety_rules(
            decision(secondary_intents=["fraude_seguridad"]),
            message("¿Cómo pago? No reconozco una compra"),
        )
        self.assertEqual(
            (result.action, result.queue, result.priority),
            ("escalar_humano", "fraude", "alta"),
        )
        self.assertIsNone(result.draft_reply)

    def test_automatic_answer_needs_matching_policy(self):
        valid = apply_safety_rules(decision(), message())
        self.assertEqual(
            valid.draft_reply,
            AUTO_ANSWERS["metodos_de_pago"]["pagos_y_cuotas.md#metodos-de-pago"],
        )

        result = apply_safety_rules(
            decision(
                main_reason="datos_personales",
                policy_refs=["pagos_y_cuotas.md#metodos-de-pago"],
            ),
            message("Quiero actualizar mi celular"),
        )
        self.assertEqual((result.action, result.queue), ("escalar_humano", "cx"))
        self.assertIsNone(result.draft_reply)

        result = apply_safety_rules(
            decision(
                policy_refs=[
                    "pagos_y_cuotas.md#metodos-de-pago",
                    "pagos_y_cuotas.md#pago-anticipado",
                ]
            ),
            message("¿A qué correo envío el comprobante?"),
        )
        self.assertEqual(
            result.draft_reply,
            "Si un pago en efectivo no se refleja en 24 horas, envía el "
            "comprobante a pagos@lumo.example.",
        )

    def test_account_specific_or_uncovered_cases_need_a_human(self):
        cases = [
            ("fecha_de_pago", "¿Cuál es mi fecha exacta?", "cx"),
            ("fecha_de_pago", "¿Me cambiaron la fecha o sigue igual?", "cx"),
            ("mora_intereses", "¿Cuánto me cobraron de mora?", "cartera"),
            ("mora_intereses", "¿Por qué me llegó un cobro extra?", "cartera"),
            ("mora_intereses", "Si pago hoy, ¿me quitan los intereses?", "cartera"),
            ("datos_personales", "Necesito cambiar mi dirección", "soporte"),
            ("certificados_extractos", "Necesito un certificado de la deuda", "cx"),
            ("certificados_extractos", "Necesito certificado de saldo a hoy", "cx"),
            ("certificados_extractos", "Reenvíen el extracto que no me llegó", "cx"),
            ("certificados_extractos", "Necesito certificado de retención", "cx"),
            ("metodos_de_pago", "¿Cuál es el número de cuenta para transferir?", "cx"),
            ("cuenta_y_app", "El código no llega y ya intenté cinco veces", "soporte"),
            ("cuenta_y_app", "Olvidé mi contraseña", "soporte"),
        ]
        for reason, text, queue in cases:
            with self.subTest(reason=reason):
                result = apply_safety_rules(decision(main_reason=reason), message(text))
                self.assertEqual(
                    (result.action, result.queue), ("escalar_humano", queue)
                )

    def test_entities_must_appear_in_the_message(self):
        result = apply_safety_rules(
            decision(
                entities={
                    "document_numbers": [],
                    "credit_ids": ["4471", "inventado"],
                    "amounts": [],
                    "dates": [],
                    "references": [],
                }
            ),
            message("Mi crédito es 4471"),
        )
        self.assertEqual(result.entities.credit_ids, ["4471"])

    def test_only_noise_or_feedback_can_be_discarded(self):
        in_scope = apply_safety_rules(
            decision(action="descartar", draft_reply=None, policy_refs=[]), message()
        )
        noise = apply_safety_rules(
            decision(
                main_reason="fuera_de_alcance",
                entities={
                    "document_numbers": [],
                    "credit_ids": [],
                    "amounts": [],
                    "dates": [],
                    "references": ["Claro"],
                },
                action="escalar_humano",
                queue="cx",
                draft_reply=None,
                policy_refs=[],
            ),
            message("vendo empanadas"),
        )
        self.assertEqual((in_scope.action, in_scope.queue), ("escalar_humano", "cx"))
        self.assertEqual((noise.action, noise.priority), ("descartar", "baja"))
        self.assertFalse(any(noise.entities.model_dump().values()))

    def test_summary_excludes_technical_errors_from_ratio(self):
        success = {
            "technical_status": "ok",
            "main_reason": "metodos_de_pago",
            "priority": "baja",
            "action": "responder_automaticamente",
            "queue": None,
        }
        summary = summarize([success, {"technical_status": "error"}])
        self.assertEqual(summary["technical_errors"], 1)
        self.assertEqual(summary["auto_answerable_ratio"], 1)


if __name__ == "__main__":
    unittest.main()
