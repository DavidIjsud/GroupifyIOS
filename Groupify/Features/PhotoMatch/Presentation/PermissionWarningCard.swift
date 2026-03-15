import SwiftUI

// MARK: - Design tokens for the warning card

private enum WarningTheme {
    static let background = Color(red: 45/255, green: 15/255, blue: 18/255)     // Dark wine red
    static let border = Color(red: 120/255, green: 30/255, blue: 40/255)        // Subtle red border
    static let iconBackground = Color(red: 180/255, green: 40/255, blue: 50/255) // Brighter red circle
    static let titleColor = Color.white
    static let descriptionColor = Color(red: 200/255, green: 170/255, blue: 170/255) // Muted pinkish
    static let buttonTextColor = Color(red: 255/255, green: 100/255, blue: 110/255)  // Bright red-pink
    static let buttonBackground = Color(red: 80/255, green: 20/255, blue: 28/255)    // Slightly lighter wine
    static let closeColor = Color(red: 160/255, green: 120/255, blue: 120/255)       // Muted close icon
    static let cornerRadius: CGFloat = 14
}

// MARK: - Reusable Warning Card

struct PermissionWarningCard: View {
    let title: String
    let message: String
    let buttonLabel: String
    let onButtonTapped: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .top, spacing: 14) {
                // Warning icon in a circular background
                ZStack {
                    Circle()
                        .fill(WarningTheme.iconBackground)
                        .frame(width: 38, height: 38)
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    // Title
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(WarningTheme.titleColor)

                    // Description
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(WarningTheme.descriptionColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Action button
                    Button(action: onButtonTapped) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 13, weight: .medium))
                            Text(buttonLabel)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(WarningTheme.buttonTextColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(WarningTheme.buttonBackground)
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 20)
            }
            .padding(16)

            // Close / dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(WarningTheme.closeColor)
                    .frame(width: 28, height: 28)
            }
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: WarningTheme.cornerRadius)
                .fill(WarningTheme.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WarningTheme.cornerRadius)
                .stroke(WarningTheme.border, lineWidth: 1)
        )
    }
}
