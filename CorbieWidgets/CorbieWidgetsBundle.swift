import SwiftUI
import WidgetKit

@main
struct CorbieWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        homeWidgets
        lockScreenWidgets
    }

    @WidgetBundleBuilder
    private var homeWidgets: some Widget {
        DaysTogetherWidget()
        CountdownWidget()
        TasksWidget()
        FreeTasksWidget()
        PartnerWishesWidget()
        PlanProgressWidget()
        UpcomingDatesWidget()
        ShoppingWidget()
        CapsuleWidget()
        OurDayWidget()
    }

    @WidgetBundleBuilder
    private var lockScreenWidgets: some Widget {
        LockCircularWidget()
        LockRectangularWidget()
        LockInlineWidget()
    }
}
