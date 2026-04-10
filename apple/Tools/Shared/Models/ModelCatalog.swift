import Foundation

extension ModelStore {
    static let catalog: [CuratedModel] = [
        // LLMs
        CuratedModel(
            id: "mlx-community/Qwen3-30B-A3B-4bit",
            name: "Qwen 3 30B-A3B",
            summary: "30B MoE (3B active) · 4-bit",
            size: "17.2 GB", sizeGB: 17.2,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Mistral-Small-24B-Instruct-2501-4bit",
            name: "Mistral Small 24B",
            summary: "24B params · 4-bit",
            size: "13.3 GB", sizeGB: 13.3,
            avatar: "mistralai",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-14B-4bit",
            name: "Qwen 3 14B",
            summary: "14B params · 4-bit",
            size: "8.32 GB", sizeGB: 8.32,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit",
            name: "Mistral Nemo",
            summary: "12B params · 4-bit",
            size: "6.91 GB", sizeGB: 6.91,
            avatar: "mistralai",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/gemma-2-9b-it-4bit",
            name: "Gemma 2 9B",
            summary: "9B params · 4-bit",
            size: "5.22 GB", sizeGB: 5.22,
            avatar: "google",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-8B-4bit",
            name: "Qwen 3 8B",
            summary: "8B params · 4-bit",
            size: "4.62 GB", sizeGB: 4.62,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            name: "Llama 3.1 8B",
            summary: "8B params · 4-bit",
            size: "4.52 GB", sizeGB: 4.52,
            avatar: "meta-llama",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-4B-4bit",
            name: "Qwen 3 4B",
            summary: "4B params · 4-bit",
            size: "2.28 GB", sizeGB: 2.28,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Phi-4-mini-instruct-4bit",
            name: "Phi 4 Mini",
            summary: "3.8B params · 4-bit",
            size: "2.18 GB", sizeGB: 2.18,
            avatar: "microsoft",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B",
            summary: "3B params · 4-bit",
            size: "1.82 GB", sizeGB: 1.82,
            avatar: "meta-llama",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/gemma-2-2b-it-4bit",
            name: "Gemma 2 2B",
            summary: "2B params · 4-bit",
            size: "1.49 GB", sizeGB: 1.49,
            avatar: "google",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-1.7B-4bit",
            name: "Qwen 3 1.7B",
            summary: "1.7B params · 4-bit",
            size: "984 MB", sizeGB: 0.96,
            avatar: "qwen",
            kind: .llm
        ),

        // VLMs
        CuratedModel(
            id: "mlx-community/Qwen2.5-VL-7B-Instruct-4bit",
            name: "Qwen 2.5 VL 7B",
            summary: "7B params · 4-bit · Vision",
            size: "5.65 GB", sizeGB: 5.65,
            avatar: "qwen",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
            name: "Qwen 2.5 VL 3B",
            summary: "3B params · 4-bit · Vision",
            size: "3.09 GB", sizeGB: 3.09,
            avatar: "qwen",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/gemma-3-4b-it-qat-4bit",
            name: "Gemma 3 4B",
            summary: "4B params · 4-bit · Vision",
            size: "3.03 GB", sizeGB: 3.03,
            avatar: "google",
            kind: .vlm
        ),

        // STT (Speech-to-Text)
        CuratedModel(
            id: "mlx-community/whisper-large-v3-mlx",
            name: "Whisper Large V3",
            summary: "1.5B params · Speech-to-Text",
            size: "3.08 GB", sizeGB: 3.08,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-large-v3-turbo",
            name: "Whisper Large V3 Turbo",
            summary: "809M params · Speech-to-Text",
            size: "1.61 GB", sizeGB: 1.61,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-small-mlx",
            name: "Whisper Small",
            summary: "244M params · Speech-to-Text",
            size: "481 MB", sizeGB: 0.47,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-tiny-mlx",
            name: "Whisper Tiny",
            summary: "39M params · Speech-to-Text",
            size: "74.4 MB", sizeGB: 0.07,
            avatar: "openai",
            kind: .stt
        ),
    ]

    #if os(iOS)
    static let available = catalog.filter { $0.sizeGB <= 4.0 }
    #else
    static let available = catalog
    #endif
}
