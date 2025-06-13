import SwiftUI

struct StatusBadge: View {
    let status: MeetingStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: status.color).opacity(0.2))
            .foregroundColor(Color(hex: status.color))
            .clipShape(Capsule())
    }
} 