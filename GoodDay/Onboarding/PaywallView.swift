import SwiftUI

struct PaywallView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var selectedPlan: Plan = .yearly

    enum Plan {
        case monthly
        case yearly
    }

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 16) {
                Text("Unlock Full Journal")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Get unlimited entries, iCloud sync, and advanced insights.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Mockup Plans
            VStack(spacing: 12) {
                planButton(
                    title: "Monthly",
                    price: "$4.99/mo",
                    isSelected: selectedPlan == .monthly
                ) {
                    selectedPlan = .monthly
                }

                planButton(
                    title: "Yearly (Best Value)",
                    price: "$39.99/yr",
                    isSelected: selectedPlan == .yearly
                ) {
                    selectedPlan = .yearly
                }
            }
            .padding(.vertical)

            Spacer()

            VStack(spacing: 16) {
                Button("Start Free Trial") {
                    // Simulate Purchase Logic
                    viewModel.isPremium = true
                    viewModel.completeStep(.paywall)
                }
                .buttonStyle(OnboardingButtonStyle())

                Button("Continue with Limited Version") {
                    viewModel.isPremium = false
                    viewModel.completeStep(.paywall)
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    func planButton(title: String, price: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                Spacer()
                Text(price)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 2)
                    .background(isSelected ? Color.blue.opacity(0.05) : Color.clear)
            )
            .padding(.horizontal)
        }
    }
}
