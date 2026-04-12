import JavaScriptCore
import SwiftUI

struct ScriptPreviewView: View {
    let script: String
    @State private var input = "Hello World\n  Lorem ipsum dolor sit amet\nfooBAR\nthe quick brown fox"
    @State private var output = ""
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Output")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(error ?? output)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(error != nil ? .red : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
                        .padding(6)
                        .background(.fill.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .onChange(of: input) { runPreview() }
        .onChange(of: script) { runPreview() }
        .onAppear { runPreview() }
    }

    private func runPreview() {
        let context = JSContext()!
        var jsError: String?
        context.exceptionHandler = { _, exception in
            jsError = exception?.toString()
        }
        context.setObject(input, forKeyedSubscript: "input" as NSString)
        context.evaluateScript(script)

        if let jsError {
            error = jsError
            output = ""
        } else if let result = context.objectForKeyedSubscript("output"),
                  !result.isUndefined, !result.isNull {
            error = nil
            output = result.toString() ?? ""
        } else {
            error = nil
            output = ""
        }
    }
}
