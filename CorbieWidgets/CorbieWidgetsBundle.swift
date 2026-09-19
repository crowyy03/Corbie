import CorbieCore
import SwiftUI
import WidgetKit

@main
struct CorbieWidgetsBundle: WidgetBundle {
    init() {
        _ = StorageProbe.run(process: "widgets")
        ServerConfiguration.fromBundle().announce(process: "widgets")
    }

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
        QuestionSmallWidget()
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
        QuestionMediumWidget()
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
