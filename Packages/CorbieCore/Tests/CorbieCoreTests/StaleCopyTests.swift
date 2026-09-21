import Foundation
import Testing
@testable import CorbieCore

@Suite struct StaleCopyTests {
    private let older = Date(timeIntervalSince1970: 1_500_000_000)
    private let newer = Date(timeIntervalSince1970: 1_600_000_000)
    private let later = Date(timeIntervalSince1970: 1_900_000_000)

    @Test func theAnniversaryFromTheOtherPhoneSurvivesACurrencyChangeFromAStaleCopy() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        let stale = try await spaces.setTogetherSince(spaceId: world.space.id, older)
        try await OtherContext.change(Space.entityName, id: world.space.id, in: world.controller) { (space: Space) in
            space.togetherSince = newer
        }

        var edited = stale
        edited.displayCurrency = "EUR"
        let saved = try await spaces.update(edited, from: stale)

        #expect(saved.togetherSince == newer)
        #expect(saved.displayCurrency == "EUR")
        let stored = try #require(try await spaces.space(id: world.space.id))
        #expect(stored.togetherSince == newer)
        #expect(stored.displayCurrency == "EUR")
    }

    @Test func theSettingsCurrencyWriteLeavesTheAnniversaryAlone() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        _ = try await spaces.setTogetherSince(spaceId: world.space.id, older)
        try await OtherContext.change(Space.entityName, id: world.space.id, in: world.controller) { (space: Space) in
            space.togetherSince = newer
            space.weddingDate = later
        }

        let saved = try await spaces.setDisplayCurrency(spaceId: world.space.id, "GBP")

        #expect(saved.togetherSince == newer)
        #expect(saved.weddingDate == later)
        #expect(saved.displayCurrency == "GBP")
    }

    @Test func aStaleActiveCopyCannotBringBackAnExpiredSubscription() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        let stale = try await spaces.setSubscription(
            spaceId: world.space.id,
            status: .active,
            expiresAt: later,
            payerMemberId: world.me.id
        )
        _ = try await spaces.setSubscription(
            spaceId: world.space.id,
            status: .expired,
            expiresAt: newer,
            payerMemberId: world.me.id
        )

        var edited = stale
        edited.displayCurrency = "EUR"
        let saved = try await spaces.update(edited, from: stale)

        #expect(saved.subscriptionStatus == .expired)
        #expect(saved.subscriptionExpiresAt == newer)
        #expect(saved.displayCurrency == "EUR")
    }

    @Test func aStaleExpiredCopyCannotRevokeAnActivePair() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        let stale = try await spaces.setSubscription(
            spaceId: world.space.id,
            status: .expired,
            expiresAt: newer,
            payerMemberId: world.me.id
        )
        _ = try await spaces.setSubscription(
            spaceId: world.space.id,
            status: .active,
            expiresAt: later,
            payerMemberId: world.partner.id
        )

        var edited = stale
        edited.displayCurrency = "EUR"
        let saved = try await spaces.update(edited, from: stale)

        #expect(saved.subscriptionStatus == .active)
        #expect(saved.subscriptionExpiresAt == later)
        #expect(saved.subscriptionPayerMemberId == world.partner.id)
    }

    @Test func noUpdatePathWritesTheFiveProtectedSpaceFields() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        let creator = try await spaces.setCreatorIfUnset(spaceId: world.space.id, memberId: world.me.id)
        let protected = try await spaces.setSubscription(
            spaceId: world.space.id,
            status: .trial,
            expiresAt: later,
            payerMemberId: world.me.id
        )
        let anchor = try #require(creator.anchorTimeZone)

        var edited = protected
        edited.creatorMemberId = world.partner.id
        edited.anchorTimeZone = anchor == "UTC" ? "Pacific/Kiritimati" : "UTC"
        edited.subscriptionStatus = .expired
        edited.subscriptionExpiresAt = older
        edited.subscriptionPayerMemberId = world.partner.id
        edited.weddingDate = newer
        _ = try await spaces.update(edited, from: protected)
        _ = try await spaces.setTogetherSince(spaceId: world.space.id, older)
        _ = try await spaces.setTogetherSinceIfUnset(spaceId: world.space.id, newer)
        _ = try await spaces.setWeddingDate(spaceId: world.space.id, later)
        _ = try await spaces.setDisplayCurrency(spaceId: world.space.id, "CHF")
        _ = try await spaces.setCreatorIfUnset(spaceId: world.space.id, memberId: world.partner.id)

        let stored = try #require(try await spaces.space(id: world.space.id))
        #expect(stored.creatorMemberId == world.me.id)
        #expect(stored.anchorTimeZone == anchor)
        #expect(stored.subscriptionStatus == .trial)
        #expect(stored.subscriptionExpiresAt == later)
        #expect(stored.subscriptionPayerMemberId == world.me.id)
        #expect(stored.togetherSince == older)
        #expect(stored.weddingDate == later)
        #expect(stored.displayCurrency == "CHF")
    }

    @Test func theCreatorIsSetOnceWhenMissing() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        #expect(world.space.creatorMemberId == nil)
        let first = try await spaces.setCreatorIfUnset(spaceId: world.space.id, memberId: world.me.id)
        let second = try await spaces.setCreatorIfUnset(spaceId: world.space.id, memberId: world.partner.id)
        #expect(first.creatorMemberId == world.me.id)
        #expect(second.creatorMemberId == world.me.id)
    }

    @Test func aCarriedAnniversaryNeverReplacesOneAlreadyStored() async throws {
        let world = try await TestWorld.make()
        let spaces = world.repositories.spaces
        let filled = try await spaces.setTogetherSinceIfUnset(spaceId: world.space.id, older)
        let kept = try await spaces.setTogetherSinceIfUnset(spaceId: world.space.id, newer)
        #expect(filled.togetherSince == older)
        #expect(kept.togetherSince == older)
    }

    @Test func aStaleProfileEditKeepsTheBirthdayAndPrefsFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let members = world.repositories.members
        let stale = world.me
        var quiet = NotificationPrefs.allEnabled
        quiet.voteUpdates = false
        try await OtherContext.change(Member.entityName, id: stale.id, in: world.controller) { (member: Member) in
            member.birthdayMonth = 4
            member.birthdayDay = 12
            member.notificationPrefs = quiet
        }

        var edited = stale
        edited.displayName = "Ilya V"
        let saved = try await members.update(edited, from: stale, theme: .sand).member

        #expect(saved.displayName == "Ilya V")
        #expect(saved.birthdayMonth == 4)
        #expect(saved.birthdayDay == 12)
        #expect(saved.notificationPrefs == quiet)
        #expect(saved.colorSlot == stale.colorSlot)
    }

    @Test func theFieldLevelProfileWritesTouchOnlyTheirField() async throws {
        let world = try await TestWorld.make()
        let members = world.repositories.members
        try await OtherContext.change(Member.entityName, id: world.me.id, in: world.controller) { (member: Member) in
            member.displayName = "Ilya from the iPad"
        }

        _ = try await members.setBirthday(memberId: world.me.id, month: 6, day: 20)
        let colored = try await members.setColor(
            memberId: world.me.id,
            colorKey: MemberColorSlot.blue.rawValue,
            theme: .sand
        ).member

        #expect(colored.displayName == "Ilya from the iPad")
        #expect(colored.birthdayMonth == 6)
        #expect(colored.birthdayDay == 20)
        #expect(colored.colorSlot == .blue)
        let named = try await members.setDisplayName(memberId: world.me.id, "Ilya")
        #expect(named.displayName == "Ilya")
        #expect(named.colorSlot == .blue)
        #expect(named.birthdayMonth == 6)
    }

    @Test func aStaleTaskEditKeepsThePartnersTakeAndDone() async throws {
        let world = try await TestWorld.make()
        let tasks = world.repositories.tasks
        let stale = try await tasks.create(TaskDraft(spaceId: world.space.id, title: "Buy milk"))
        let partnerId = world.partner.id
        try await OtherContext.change(TaskItem.entityName, id: stale.id, in: world.controller) { (task: TaskItem) in
            task.assigneeMemberId = partnerId
            task.takenAt = newer
            task.isDone = true
            task.doneByMemberId = partnerId
            task.doneAt = newer
        }

        var edited = stale
        edited.title = "Buy oat milk"
        let saved = try await tasks.update(edited, from: stale)

        #expect(saved.title == "Buy oat milk")
        #expect(saved.assigneeMemberId == partnerId)
        #expect(saved.takenAt == newer)
        #expect(saved.isDone)
        #expect(saved.doneByMemberId == partnerId)
    }

    @Test func anAssigneeChangedInTheEditorIsWritten() async throws {
        let world = try await TestWorld.make()
        let tasks = world.repositories.tasks
        let stale = try await tasks.create(TaskDraft(spaceId: world.space.id, title: "Call the plumber"))
        var edited = stale
        edited.assigneeMemberId = world.me.id
        let saved = try await tasks.update(edited, from: stale)
        #expect(saved.assigneeMemberId == world.me.id)
    }

    @Test func aStaleWishEditKeepsTheGiftFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let wishes = world.repositories.wishes
        let stale = try await wishes.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.partner.id, title: "Kettle")
        )
        try await OtherContext.change(Wish.entityName, id: stale.id, in: world.controller) { (wish: Wish) in
            wish.isFulfilled = true
            wish.fulfilledAt = newer
            wish.price = 80
        }

        var edited = stale
        edited.note = "the matte one"
        let saved = try await wishes.update(edited, from: stale)

        #expect(saved.note == "the matte one")
        #expect(saved.isFulfilled)
        #expect(saved.fulfilledAt == newer)
        #expect(saved.price == 80)
    }

    @Test func aStaleEventEditKeepsTheTimeMovedElsewhere() async throws {
        let world = try await TestWorld.make()
        let events = world.repositories.events
        let stale = try await events.create(
            EventDraft(spaceId: world.space.id, title: "Dinner", startAt: older, endAt: older.addingTimeInterval(3600))
        )
        try await OtherContext.change(Event.entityName, id: stale.id, in: world.controller) { (event: Event) in
            event.startAt = newer
            event.endAt = newer.addingTimeInterval(7200)
            event.locationName = "Belem"
        }

        var edited = stale
        edited.title = "Dinner at Anna's"
        let saved = try await events.update(edited, from: stale)

        #expect(saved.title == "Dinner at Anna's")
        #expect(saved.startAt == newer)
        #expect(saved.endAt == newer.addingTimeInterval(7200))
        #expect(saved.locationName == "Belem")
    }

    @Test func aStaleCapsuleEditKeepsTheOpeningDayChangedElsewhere() async throws {
        let world = try await TestWorld.make()
        let capsules = world.repositories.capsules
        let now = older
        let stale = try await capsules.create(
            CapsuleDraft(spaceId: world.space.id, title: "Letter", body: "See you", opensAt: newer),
            now: now
        )
        try await OtherContext.change(CapsuleItem.entityName, id: stale.id, in: world.controller) { (capsule: CapsuleItem) in
            capsule.opensAt = later
        }

        var edited = stale
        edited.title = "Letter for the spring"
        let saved = try await capsules.update(edited, from: stale, now: now)

        #expect(saved.title == "Letter for the spring")
        #expect(saved.opensAt == later)
        #expect(saved.body == "See you")
    }

    @Test func aStalePersonEditKeepsTheBirthdayChangedElsewhere() async throws {
        let world = try await TestWorld.make()
        let people = world.repositories.people
        let stale = try await people.create(PersonDraft(spaceId: world.space.id, name: "Anna"))
        try await OtherContext.change(Person.entityName, id: stale.id, in: world.controller) { (person: Person) in
            person.birthdayMonth = 3
            person.birthdayDay = 14
        }

        var edited = stale
        edited.note = "likes tea"
        let saved = try await people.update(edited, from: stale)

        #expect(saved.note == "likes tea")
        #expect(saved.birthdayMonth == 3)
        #expect(saved.birthdayDay == 14)
    }

    @Test func aStalePersonDateEditKeepsTheReminderSwitchFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let people = world.repositories.people
        let person = try await people.create(PersonDraft(spaceId: world.space.id, name: "Anna"))
        let stale = try await people.addDate(
            personId: person.id,
            draft: PersonDateDraft(title: "name day", month: 2, day: 3)
        )
        try await OtherContext.change(PersonDate.entityName, id: stale.id, in: world.controller) { (date: PersonDate) in
            date.remindersEnabled = false
        }

        var edited = stale
        edited.title = "saint's day"
        let saved = try await people.updateDate(edited, from: stale)

        #expect(saved.title == "saint's day")
        #expect(saved.remindersEnabled == false)
    }

    @Test func aStaleGiftIdeaEditKeepsThePickFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let people = world.repositories.people
        let person = try await people.create(PersonDraft(spaceId: world.space.id, name: "Anna"))
        let stale = try await people.addGiftIdea(personId: person.id, draft: GiftIdeaDraft(title: "Mug"))
        try await OtherContext.change(GiftIdea.entityName, id: stale.id, in: world.controller) { (idea: GiftIdea) in
            idea.isDone = true
        }

        var edited = stale
        edited.price = 24
        edited.currency = "EUR"
        let saved = try await people.updateGiftIdea(edited, from: stale)

        #expect(saved.price == 24)
        #expect(saved.isDone)
        let unpicked = try await people.setGiftIdeaDone(ideaId: stale.id, isDone: false)
        #expect(unpicked.isDone == false)
        #expect(unpicked.price == 24)
    }

    @Test func aStalePlanEditKeepsTheSavedAmountAndTheStatusFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let plans = world.repositories.plans
        let stale = try await plans.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                type: .trip,
                targetAmount: 2000,
                currency: "USD",
                savedAmount: 300
            )
        )
        _ = try await plans.addExpense(
            planId: stale.id,
            draft: PlanExpenseDraft(amount: 150, currency: "USD", addedByMemberId: world.partner.id)
        )
        try await OtherContext.change(Plan.entityName, id: stale.id, in: world.controller) { (plan: Plan) in
            plan.savedAmount = 800
            plan.status = .completed
        }

        var edited = stale
        edited.note = "window seats"
        let saved = try await plans.update(edited, from: stale)

        #expect(saved.note == "window seats")
        #expect(saved.savedAmount == 800)
        #expect(saved.status == .completed)
        #expect(saved.addedAmount == 150)
        #expect(saved.targetAmount == 2000)
    }

    @Test func noPlanUpdateWritesTheSavedAmountOrTheStatus() async throws {
        let world = try await TestWorld.make()
        let plans = world.repositories.plans
        let original = try await plans.create(
            PlanDraft(spaceId: world.space.id, title: "Sofa", targetAmount: 900, currency: "EUR", savedAmount: 100)
        )

        var edited = original
        edited.title = "Green sofa"
        edited.savedAmount = 5000
        edited.status = .archived
        let saved = try await plans.update(edited, from: original)

        #expect(saved.title == "Green sofa")
        #expect(saved.savedAmount == 100)
        #expect(saved.status == .active)
        let moved = try await plans.setSavedAmount(planId: original.id, 250)
        let completed = try await plans.setStatus(planId: original.id, status: .completed)
        #expect(moved.savedAmount == 250)
        #expect(completed.status == .completed)
        #expect(completed.savedAmount == 250)
        #expect(completed.title == "Green sofa")
    }

    @Test func aStaleStepEditKeepsThePartnersTakeDoneAndOrder() async throws {
        let world = try await TestWorld.make()
        let plans = world.repositories.plans
        let plan = try await plans.create(PlanDraft(spaceId: world.space.id, title: "Move", targetAmount: 500))
        let stale = try await plans.addStep(planId: plan.id, draft: PlanStepDraft(title: "Book the van"))
        let other = try await plans.addStep(planId: plan.id, draft: PlanStepDraft(title: "Buy boxes"))
        _ = try await plans.reorderSteps(planId: plan.id, orderedStepIds: [other.id, stale.id])
        let partnerId = world.partner.id
        try await OtherContext.change(PlanStep.entityName, id: stale.id, in: world.controller) { (step: PlanStep) in
            step.assigneeMemberId = partnerId
            step.isDone = true
            step.doneByMemberId = partnerId
            step.doneAt = newer
        }

        var edited = stale
        edited.note = "the big one"
        let saved = try await plans.updateStep(edited, from: stale)

        #expect(saved.note == "the big one")
        #expect(saved.title == "Book the van")
        #expect(saved.assigneeMemberId == partnerId)
        #expect(saved.isDone)
        #expect(saved.doneByMemberId == partnerId)
        #expect(saved.sortIndex == 1)
    }

    @Test func aStaleListEditKeepsWhoCanTickFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let lists = world.repositories.lists
        let stale = try await lists.create(
            ChecklistDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                template: .places,
                createdByMemberId: world.me.id
            )
        )
        try await OtherContext.change(ChecklistList.entityName, id: stale.id, in: world.controller) { (list: ChecklistList) in
            list.anyoneCanCheck = false
            list.subtitle = "in May"
        }

        var edited = stale
        edited.title = "Lisbon and Porto"
        let saved = try await lists.update(edited, from: stale)

        #expect(saved.title == "Lisbon and Porto")
        #expect(saved.anyoneCanCheck == false)
        #expect(saved.subtitle == "in May")
        #expect(saved.template == .places)
    }

    @Test func aStaleItemEditKeepsTheTickTheOrderAndThePlaceFromElsewhere() async throws {
        let world = try await TestWorld.make()
        let lists = world.repositories.lists
        let list = try await lists.create(ChecklistDraft(spaceId: world.space.id, title: "Lisbon", template: .places))
        let stale = try await lists.addItem(listId: list.id, draft: ListItemDraft(title: "Time Out Market"))
        let other = try await lists.addItem(listId: list.id, draft: ListItemDraft(title: "Belem tower"))
        _ = try await lists.reorder(listId: list.id, orderedItemIds: [other.id, stale.id])
        let partnerId = world.partner.id
        try await OtherContext.change(ListItem.entityName, id: stale.id, in: world.controller) { (item: ListItem) in
            item.isChecked = true
            item.checkedByMemberId = partnerId
            item.checkedAt = newer
            item.placeName = "Time Out Market Lisboa"
            item.address = "Av. 24 de Julho 49"
            item.latitude = 38.7069
            item.longitude = -9.1459
        }

        var edited = stale
        edited.note = "go before noon"
        let saved = try await lists.updateItem(edited, from: stale)

        #expect(saved.note == "go before noon")
        #expect(saved.isChecked)
        #expect(saved.checkedByMemberId == partnerId)
        #expect(saved.checkedAt == newer)
        #expect(saved.sortIndex == 1)
        #expect(saved.placeName == "Time Out Market Lisboa")
        #expect(saved.address == "Av. 24 de Julho 49")
        #expect(saved.latitude == 38.7069)
        #expect(saved.longitude == -9.1459)
    }

    @Test func aPlaceChosenInTheEditorReplacesTheWholePlace() async throws {
        let world = try await TestWorld.make()
        let lists = world.repositories.lists
        let list = try await lists.create(ChecklistDraft(spaceId: world.space.id, title: "Lisbon", template: .places))
        let stale = try await lists.addItem(
            listId: list.id,
            draft: ListItemDraft(
                title: "Coffee",
                placeName: "Fabrica",
                address: "Rua das Flores",
                latitude: 38.71,
                longitude: -9.14
            )
        )
        try await OtherContext.change(ListItem.entityName, id: stale.id, in: world.controller) { (item: ListItem) in
            item.address = "Rua das Flores 63"
        }

        var edited = stale
        edited.placeName = "Hello Kristof"
        edited.address = nil
        edited.latitude = 38.712
        edited.longitude = -9.147
        let saved = try await lists.updateItem(edited, from: stale)

        #expect(saved.placeName == "Hello Kristof")
        #expect(saved.address == nil)
        #expect(saved.latitude == 38.712)
        #expect(saved.longitude == -9.147)
    }

    @Test func noStepOrItemEditMovesTheRowOrTicksIt() async throws {
        let world = try await TestWorld.make()
        let plans = world.repositories.plans
        let lists = world.repositories.lists
        let plan = try await plans.create(PlanDraft(spaceId: world.space.id, title: "Move", targetAmount: 500))
        let step = try await plans.addStep(planId: plan.id, draft: PlanStepDraft(title: "Book the van"))
        let list = try await lists.create(ChecklistDraft(spaceId: world.space.id, title: "Groceries"))
        let item = try await lists.addItem(listId: list.id, draft: ListItemDraft(title: "Milk"))

        var editedStep = step
        editedStep.title = "Book the big van"
        editedStep.sortIndex = 7
        editedStep.isDone = true
        var editedItem = item
        editedItem.title = "Oat milk"
        editedItem.sortIndex = 7
        editedItem.isChecked = true
        let savedStep = try await plans.updateStep(editedStep, from: step)
        let savedItem = try await lists.updateItem(editedItem, from: item)

        #expect(savedStep.title == "Book the big van")
        #expect(savedStep.sortIndex == step.sortIndex)
        #expect(savedStep.isDone == false)
        #expect(savedItem.title == "Oat milk")
        #expect(savedItem.sortIndex == item.sortIndex)
        #expect(savedItem.isChecked == false)
    }

    @Test func settingATickTwiceKeepsTheFirstOne() async throws {
        let world = try await TestWorld.make()
        let lists = world.repositories.lists
        let list = try await lists.create(ChecklistDraft(spaceId: world.space.id, title: "Groceries"))
        let item = try await lists.addItem(listId: list.id, draft: ListItemDraft(title: "Milk"))

        let first = try await lists.setItemChecked(itemId: item.id, true, memberId: world.partner.id, at: older)
        let second = try await lists.setItemChecked(itemId: item.id, true, memberId: world.me.id, at: newer)

        #expect(first.isChecked)
        #expect(second.checkedByMemberId == world.partner.id)
        #expect(second.checkedAt == older)
    }

    @Test func anEditedCopyOfAnotherRowIsRefused() async throws {
        let world = try await TestWorld.make()
        let tasks = world.repositories.tasks
        let first = try await tasks.create(TaskDraft(spaceId: world.space.id, title: "One"))
        let second = try await tasks.create(TaskDraft(spaceId: world.space.id, title: "Two"))
        await #expect(throws: CorbieError.invalidInput("the edited copy and the original are different rows")) {
            _ = try await tasks.update(first, from: second)
        }
    }
}

@Suite struct WishLinkRefillTests {
    private let link = "https://www.etsy.com/listing/1"

    private func pendingWish(_ world: TestWorld, title: String = "") async throws -> WishDTO {
        try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.me.id,
                title: title,
                url: link,
                needsParse: true
            )
        )
    }

    private func parsed(title: String? = "Apron, sand", image: Bool = true) throws -> ParsedLink {
        ParsedLink(
            canonicalURL: try #require(URL(string: "https://www.etsy.com/listing/1-apron")),
            source: .etsy,
            title: title,
            price: 48,
            currency: "usd",
            imageURL: image ? URL(string: "https://img.example.com/1.jpg") : nil,
            imageData: image ? Data([1, 2, 3]) : nil
        )
    }

    @Test func aTitleTypedAfterTheSnapshotSurvivesTheRefill() async throws {
        let world = try await TestWorld.make()
        let wishes = world.repositories.wishes
        let snapshot = try await pendingWish(world)
        try await OtherContext.change(Wish.entityName, id: snapshot.id, in: world.controller) { (wish: Wish) in
            wish.title = "Linen apron"
            wish.price = 30
            wish.currency = "EUR"
        }

        let filled = try await wishes.fillEmptyFields(wishId: snapshot.id, parsedFrom: link, with: try parsed())

        #expect(filled.title == "Linen apron")
        #expect(filled.price == 30)
        #expect(filled.currency == "EUR")
        #expect(filled.imageURL == "https://img.example.com/1.jpg")
        #expect(filled.localImage == Data([1, 2, 3]))
        #expect(filled.source == .etsy)
        #expect(filled.url == link)
        #expect(filled.needsParse == false)
    }

    @Test func anEmptyTitleIsFilled() async throws {
        let world = try await TestWorld.make()
        let snapshot = try await pendingWish(world)

        let filled = try await world.repositories.wishes.fillEmptyFields(
            wishId: snapshot.id,
            parsedFrom: link,
            with: try parsed()
        )

        #expect(filled.title == "Apron, sand")
        #expect(filled.price == 48)
        #expect(filled.currency == "USD")
        #expect(filled.needsParse == false)
    }

    @Test func anEmptyResultChangesNothingAndKeepsTheRetry() async throws {
        let world = try await TestWorld.make()
        let snapshot = try await pendingWish(world)
        let empty = try parsed(title: nil, image: false)
        #expect(empty.isEmpty)

        let result = try await world.repositories.wishes.fillEmptyFields(wishId: snapshot.id, parsedFrom: link, with: empty)

        #expect(result == snapshot)
        #expect(result.needsParse)
        #expect(result.price == nil)
        #expect(result.source == .manual)
    }

    @Test func aLinkChangedAfterTheSnapshotIsNotFilledFromTheOldOne() async throws {
        let world = try await TestWorld.make()
        let snapshot = try await pendingWish(world)
        try await OtherContext.change(Wish.entityName, id: snapshot.id, in: world.controller) { (wish: Wish) in
            wish.url = "https://www.etsy.com/listing/2"
        }

        let result = try await world.repositories.wishes.fillEmptyFields(
            wishId: snapshot.id,
            parsedFrom: link,
            with: try parsed()
        )

        #expect(result.title.isEmpty)
        #expect(result.needsParse)
    }
}
