import SwiftUI

struct HydraulicResult {
    let velocity: Double
    let reynolds: Double
    let frictionFactor: Double
    let majorLoss: Double
    let minorLoss: Double
    let totalHeadLoss: Double
    let pressureDropBar: Double
}

struct ContentView: View {
    @State private var flowM3h = "10"
    @State private var lengthM = "100"
    @State private var diameterMm = "50"
    @State private var roughnessMm = "0.045"
    @State private var density = "998"
    @State private var viscosityMpas = "1.0"
    @State private var kTotal = "2.0"
    @State private var result: HydraulicResult?
    @State private var errorMessage: String?

    private let navy = Color(red: 0.06, green: 0.14, blue: 0.25)
    private let blue = Color(red: 0.10, green: 0.42, blue: 0.72)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MAS").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(.white)
                        Text("ENGENHARIA HIDRÁULICA").font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(.white.opacity(0.85))
                        Text("Calculadora de perda de carga").font(.subheadline).foregroundStyle(.white.opacity(0.9)).padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(LinearGradient(colors: [navy, blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Dados da tubulação") {
                    numberField("Vazão", value: $flowM3h, unit: "m³/h")
                    numberField("Comprimento reto", value: $lengthM, unit: "m")
                    numberField("Diâmetro interno", value: $diameterMm, unit: "mm")
                    numberField("Rugosidade absoluta", value: $roughnessMm, unit: "mm")
                }

                Section("Propriedades do fluido") {
                    numberField("Massa específica", value: $density, unit: "kg/m³")
                    numberField("Viscosidade dinâmica", value: $viscosityMpas, unit: "mPa·s")
                }

                Section("Acessórios") {
                    numberField("Soma dos coeficientes K", value: $kTotal, unit: "K")
                    Text("Informe a soma dos coeficientes de perda localizada de curvas, válvulas, entradas, saídas e conexões.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Button(action: calculate) {
                        Label("Calcular perda de carga", systemImage: "function")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(blue)
                    .tint(.white)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if let result {
                    Section("Resultados") {
                        resultRow("Velocidade", value: "\(format(result.velocity)) m/s")
                        resultRow("Número de Reynolds", value: format(result.reynolds))
                        resultRow("Fator de atrito Darcy", value: format(result.frictionFactor))
                        resultRow("Perda distribuída", value: "\(format(result.majorLoss)) mca")
                        resultRow("Perda localizada", value: "\(format(result.minorLoss)) mca")
                        resultRow("Perda de carga total", value: "\(format(result.totalHeadLoss)) mca", emphasis: true)
                        resultRow("Queda de pressão", value: "\(format(result.pressureDropBar)) bar", emphasis: true)
                    }
                    Section {
                        Text("Método: Darcy-Weisbach. Fator de atrito: \(result.reynolds < 2300 ? "64/Re (laminar)" : result.reynolds < 4000 ? "transição aproximada" : "Swamee–Jain (turbulento)").")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("Resultado teórico. Verifique condições reais, propriedades do fluido, diâmetro efetivo e dados dos fabricantes antes do dimensionamento final.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("MAS Hidráulica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") {
                        result = nil
                        errorMessage = nil
                    }
                }
            }
        }
        .tint(blue)
    }

    private func numberField(_ title: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 115)
            Text(unit).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
        }
    }

    private func resultRow(_ title: String, value: String, emphasis: Bool = false) -> some View {
        HStack {
            Text(title).fontWeight(emphasis ? .semibold : .regular)
            Spacer()
            Text(value)
                .fontWeight(emphasis ? .bold : .medium)
                .monospacedDigit()
                .foregroundStyle(emphasis ? blue : .primary)
        }
    }

    private func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.locale(Locale(identifier: "pt_BR")).precision(.fractionLength(2...4)))
    }

    private func calculate() {
        errorMessage = nil
        guard
            let q = parse(flowM3h), let length = parse(lengthM),
            let diameter = parse(diameterMm), let rough = parse(roughnessMm),
            let rho = parse(density), let muMpas = parse(viscosityMpas),
            let k = parse(kTotal),
            q > 0, length >= 0, diameter > 0, rough >= 0, rho > 0, muMpas > 0, k >= 0
        else {
            result = nil
            errorMessage = "Confira os campos. Vazão, diâmetro, massa específica e viscosidade devem ser maiores que zero; os demais não podem ser negativos."
            return
        }

        let flow = q / 3600.0
        let d = diameter / 1000.0
        let epsilon = rough / 1000.0
        let mu = muMpas / 1000.0 // mPa·s para Pa·s
        let area = Double.pi * d * d / 4.0
        let velocity = flow / area
        let reynolds = rho * velocity * d / mu
        let relativeRoughness = epsilon / d

        let f: Double
        if reynolds < 2300 {
            f = 64.0 / reynolds
        } else {
            let turbulent = 0.25 / pow(log10(relativeRoughness / 3.7 + 5.74 / pow(reynolds, 0.9)), 2)
            if reynolds < 4000 {
                let laminarAtBoundary = 64.0 / 2300.0
                let blend = (reynolds - 2300.0) / 1700.0
                f = laminarAtBoundary * (1.0 - blend) + turbulent * blend
            } else {
                f = turbulent
            }
        }

        let velocityHead = velocity * velocity / (2.0 * 9.80665)
        let major = f * (length / d) * velocityHead
        let minor = k * velocityHead
        let total = major + minor
        let pressureBar = rho * 9.80665 * total / 100000.0

        result = HydraulicResult(
            velocity: velocity,
            reynolds: reynolds,
            frictionFactor: f,
            majorLoss: major,
            minorLoss: minor,
            totalHeadLoss: total,
            pressureDropBar: pressureBar
        )
    }
}
