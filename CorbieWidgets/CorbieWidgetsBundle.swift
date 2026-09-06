import SwiftUI
import WidgetKit

@main
struct CorbieWidgetsBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        smallWidgets
        mediumWidgets
        largeWidgets
        lockScreenWidgets
    }

    @WidgetBundleBuilder
    private var smallWidgets: some Widget {
        DaysTogetherWidget()
        CountdownWidget()
        CapsuleWidget()
    }

    @WidgetBundleBuilder
    private var mediumWidgets: some Widget {
        TasksWidget()
        FreeTasksWidget()
        PartnerWishesWidget()
        PlanProgressWidget()
        UpcomingDatesWidget()
        ShoppingWidget()
        FreeSlotsWidget()
    }

    @WidgetBundleBuilder
    private var largeWidgets: some Widget {
        OurDayWidget()
    }

    @WidgetBundleBuilder
    private var lockScreenWidgets: some Widget {
        LockCircularWidget()
        LockRectangularWidget()
        LockInlineWidget()
    }
}
