//  ModelMigrationTests.swift
//  GitPulseTests

import Foundation
import SwiftData
import Testing

@testable import GitPulse

// MARK: - ContributionTests

@Suite("Contribution model")
@MainActor
struct ContributionTests {

  @Test("Creation sets all properties correctly")
  func test_contribution_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let contribution = Contribution(
      id: "evt_123",
      type: .push,
      date: date,
      repositoryName: "GitPulse",
      repositoryOwner: "octocat",
      message: "Initial commit",
      additions: 100,
      deletions: 20,
      commitCount: 3
    )

    context.insert(contribution)
    try context.save()

    let descriptor = FetchDescriptor<Contribution>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.id == "evt_123")
    #expect(result.type == .push)
    #expect(result.date == date)
    #expect(result.repositoryName == "GitPulse")
    #expect(result.repositoryOwner == "octocat")
    #expect(result.message == "Initial commit")
    #expect(result.additions == 100)
    #expect(result.deletions == 20)
    #expect(result.commitCount == 3)
  }

  @Test("ContributionType raw values match GitHub event type strings")
  func test_contributionType_rawValues_matchGitHubEventTypes() {
    #expect(Contribution.ContributionType.push.rawValue == "push")
    #expect(Contribution.ContributionType.pullRequest.rawValue == "pullRequest")
    #expect(Contribution.ContributionType.pullRequestReview.rawValue == "pullRequestReview")
    #expect(Contribution.ContributionType.issue.rawValue == "issue")
    #expect(Contribution.ContributionType.create.rawValue == "create")
    #expect(Contribution.ContributionType.fork.rawValue == "fork")
  }

  @Test("Unique constraint upserts on duplicate id")
  func test_contribution_uniqueConstraint_upsertsOnDuplicateId() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let first = Contribution(
      id: "evt_dup",
      type: .push,
      date: date,
      repositoryName: "RepoA",
      repositoryOwner: "owner1",
      additions: 10
    )
    context.insert(first)
    try context.save()

    let second = Contribution(
      id: "evt_dup",
      type: .pullRequest,
      date: date,
      repositoryName: "RepoB",
      repositoryOwner: "owner2",
      additions: 50
    )
    context.insert(second)
    try context.save()

    let descriptor = FetchDescriptor<Contribution>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].repositoryName == "RepoB")
    #expect(fetched[0].additions == 50)
  }
}

// MARK: - RepositoryTests

@Suite("Repository model")
@MainActor
struct RepositoryTests {

  @Test("Creation sets all properties correctly")
  func test_repository_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let created = Date(timeIntervalSince1970: 1_600_000_000)
    let updated = Date(timeIntervalSince1970: 1_700_000_000)
    let pushed = Date(timeIntervalSince1970: 1_699_999_000)

    let repo = Repository(
      id: 42,
      name: "GitPulse",
      fullName: "octocat/GitPulse",
      descriptionText: "A GitHub activity tracker",
      language: "Swift",
      starCount: 128,
      forkCount: 12,
      isPrivate: true,
      lastPushDate: pushed,
      createdAt: created,
      updatedAt: updated
    )

    context.insert(repo)
    try context.save()

    let descriptor = FetchDescriptor<Repository>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.id == 42)
    #expect(result.name == "GitPulse")
    #expect(result.fullName == "octocat/GitPulse")
    #expect(result.descriptionText == "A GitHub activity tracker")
    #expect(result.language == "Swift")
    #expect(result.starCount == 128)
    #expect(result.forkCount == 12)
    #expect(result.isPrivate == true)
    #expect(result.lastPushDate == pushed)
    #expect(result.createdAt == created)
    #expect(result.updatedAt == updated)
  }

  @Test("Cascade delete removes associated LanguageStats")
  func test_repository_cascadeDelete_removesLanguageStats() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let now = Date()
    let repo = Repository(
      id: 1,
      name: "TestRepo",
      fullName: "owner/TestRepo",
      createdAt: now,
      updatedAt: now
    )

    let swift = LanguageStat(name: "Swift", bytes: 50_000, color: "#F05138")
    let objc = LanguageStat(name: "Objective-C", bytes: 20_000, color: "#438EFF")
    let ruby = LanguageStat(name: "Ruby", bytes: 5_000, color: "#701516")

    repo.languages = [swift, objc, ruby]
    context.insert(repo)
    try context.save()

    let langCountBefore = try context.fetch(FetchDescriptor<LanguageStat>()).count
    #expect(langCountBefore == 3)

    context.delete(repo)
    try context.save()

    let langCountAfter = try context.fetch(FetchDescriptor<LanguageStat>()).count
    #expect(langCountAfter == 0)

    let repoCount = try context.fetch(FetchDescriptor<Repository>()).count
    #expect(repoCount == 0)
  }

  @Test("Unique constraint upserts on duplicate id")
  func test_repository_uniqueConstraint_upsertsOnDuplicateId() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let now = Date()
    let first = Repository(
      id: 99,
      name: "OriginalName",
      fullName: "owner/OriginalName",
      starCount: 5,
      createdAt: now,
      updatedAt: now
    )
    context.insert(first)
    try context.save()

    let second = Repository(
      id: 99,
      name: "UpdatedName",
      fullName: "owner/UpdatedName",
      starCount: 25,
      createdAt: now,
      updatedAt: now
    )
    context.insert(second)
    try context.save()

    let descriptor = FetchDescriptor<Repository>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].name == "UpdatedName")
    #expect(fetched[0].starCount == 25)
  }
}

// MARK: - LanguageStatTests

@Suite("LanguageStat model")
@MainActor
struct LanguageStatTests {

  @Test("Creation sets all properties correctly")
  func test_languageStat_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let stat = LanguageStat(name: "Swift", bytes: 150_000, color: "#F05138")
    context.insert(stat)
    try context.save()

    let descriptor = FetchDescriptor<LanguageStat>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.name == "Swift")
    #expect(result.bytes == 150_000)
    #expect(result.color == "#F05138")
  }

  @Test("Inverse relationship links LanguageStat back to Repository")
  func test_languageStat_inverseRelationship_linksToRepository() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let now = Date()
    let repo = Repository(
      id: 10,
      name: "SwiftRepo",
      fullName: "dev/SwiftRepo",
      createdAt: now,
      updatedAt: now
    )

    let stat = LanguageStat(name: "Swift", bytes: 80_000, color: "#F05138")
    repo.languages.append(stat)

    context.insert(repo)
    try context.save()

    let descriptor = FetchDescriptor<LanguageStat>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].repository?.id == 10)
    #expect(fetched[0].repository?.name == "SwiftRepo")
  }
}

// MARK: - PullRequestTests

@Suite("PullRequest model")
@MainActor
struct PullRequestTests {

  @Test("Creation sets all properties correctly")
  func test_pullRequest_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let created = Date(timeIntervalSince1970: 1_700_000_000)
    let merged = Date(timeIntervalSince1970: 1_700_003_600)
    let closed = Date(timeIntervalSince1970: 1_700_003_600)

    let pr = PullRequest(
      id: 777,
      number: 42,
      title: "Add contribution heatmap",
      state: .merged,
      repositoryFullName: "octocat/GitPulse",
      createdAt: created,
      mergedAt: merged,
      closedAt: closed,
      additions: 350,
      deletions: 40,
      changedFiles: 8,
      isDraft: false
    )

    context.insert(pr)
    try context.save()

    let descriptor = FetchDescriptor<PullRequest>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.id == 777)
    #expect(result.number == 42)
    #expect(result.title == "Add contribution heatmap")
    #expect(result.state == .merged)
    #expect(result.repositoryFullName == "octocat/GitPulse")
    #expect(result.createdAt == created)
    #expect(result.mergedAt == merged)
    #expect(result.closedAt == closed)
    #expect(result.additions == 350)
    #expect(result.deletions == 40)
    #expect(result.changedFiles == 8)
    #expect(result.isDraft == false)
  }

  @Test("timeToMerge returns duration when PR is merged")
  func test_pullRequest_timeToMerge_returnsDurationWhenMerged() {
    let created = Date(timeIntervalSince1970: 1_700_000_000)
    let merged = Date(timeIntervalSince1970: 1_700_003_600)

    let pr = PullRequest(
      id: 1,
      number: 1,
      title: "Test PR",
      state: .merged,
      repositoryFullName: "owner/repo",
      createdAt: created,
      mergedAt: merged
    )

    #expect(pr.timeToMerge == 3600)
  }

  @Test("timeToMerge returns nil when PR is not merged")
  func test_pullRequest_timeToMerge_returnsNilWhenNotMerged() {
    let pr = PullRequest(
      id: 2,
      number: 2,
      title: "Open PR",
      state: .open,
      repositoryFullName: "owner/repo",
      createdAt: Date()
    )

    #expect(pr.timeToMerge == nil)
  }

  @Test("Unique constraint upserts on duplicate id")
  func test_pullRequest_uniqueConstraint_upsertsOnDuplicateId() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let now = Date()
    let first = PullRequest(
      id: 500,
      number: 10,
      title: "Original Title",
      state: .open,
      repositoryFullName: "owner/repo",
      createdAt: now
    )
    context.insert(first)
    try context.save()

    let second = PullRequest(
      id: 500,
      number: 10,
      title: "Updated Title",
      state: .merged,
      repositoryFullName: "owner/repo",
      createdAt: now,
      mergedAt: now
    )
    context.insert(second)
    try context.save()

    let descriptor = FetchDescriptor<PullRequest>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].title == "Updated Title")
    #expect(fetched[0].state == .merged)
  }

  @Test("PRState raw values match expected strings")
  func test_pullRequest_prState_rawValues() {
    #expect(PullRequest.PRState.open.rawValue == "open")
    #expect(PullRequest.PRState.merged.rawValue == "merged")
    #expect(PullRequest.PRState.closed.rawValue == "closed")
  }
}

// MARK: - UserProfileTests

@Suite("UserProfile model")
@MainActor
struct UserProfileTests {

  @Test("Creation sets all properties correctly")
  func test_userProfile_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let syncDate = Date(timeIntervalSince1970: 1_700_000_000)
    let profile = UserProfile(
      username: "octocat",
      avatarURL: "https://avatars.githubusercontent.com/u/1?v=4",
      displayName: "The Octocat",
      bio: "I love coding",
      publicRepoCount: 42,
      followerCount: 1000,
      currentStreak: 15,
      longestStreak: 90,
      activeDays: 200,
      totalContributions: 3500,
      lastSyncDate: syncDate
    )

    context.insert(profile)
    try context.save()

    let descriptor = FetchDescriptor<UserProfile>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.username == "octocat")
    #expect(result.avatarURL == "https://avatars.githubusercontent.com/u/1?v=4")
    #expect(result.displayName == "The Octocat")
    #expect(result.bio == "I love coding")
    #expect(result.publicRepoCount == 42)
    #expect(result.followerCount == 1000)
    #expect(result.currentStreak == 15)
    #expect(result.longestStreak == 90)
    #expect(result.activeDays == 200)
    #expect(result.totalContributions == 3500)
    #expect(result.lastSyncDate == syncDate)
  }

  @Test("Unique constraint upserts on duplicate username")
  func test_userProfile_uniqueConstraint_upsertsOnDuplicateUsername() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let first = UserProfile(
      username: "octocat",
      avatarURL: "https://old-avatar.com",
      currentStreak: 5
    )
    context.insert(first)
    try context.save()

    let second = UserProfile(
      username: "octocat",
      avatarURL: "https://new-avatar.com",
      currentStreak: 10
    )
    context.insert(second)
    try context.save()

    let descriptor = FetchDescriptor<UserProfile>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].avatarURL == "https://new-avatar.com")
    #expect(fetched[0].currentStreak == 10)
  }

  @Test("Default values are zero for Ints and nil for optionals")
  func test_userProfile_defaultValues_areZeroAndNil() {
    let profile = UserProfile(
      username: "minimal",
      avatarURL: "https://example.com/avatar.png"
    )

    #expect(profile.publicRepoCount == 0)
    #expect(profile.followerCount == 0)
    #expect(profile.currentStreak == 0)
    #expect(profile.longestStreak == 0)
    #expect(profile.activeDays == 0)
    #expect(profile.totalContributions == 0)
    #expect(profile.displayName == nil)
    #expect(profile.bio == nil)
    #expect(profile.lastSyncDate == nil)
  }
}

// MARK: - SyncMetadataTests

@Suite("SyncMetadata model")
@MainActor
struct SyncMetadataTests {

  @Test("Creation sets all properties correctly")
  func test_syncMetadata_creation_setsAllProperties() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let syncDate = Date(timeIntervalSince1970: 1_700_000_000)
    let resetDate = Date(timeIntervalSince1970: 1_700_003_600)

    let metadata = SyncMetadata(
      key: "lastSync",
      date: syncDate,
      eventsProcessed: 150,
      rateLimitRemaining: 4850,
      rateLimitReset: resetDate
    )

    context.insert(metadata)
    try context.save()

    let descriptor = FetchDescriptor<SyncMetadata>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    let result = fetched[0]
    #expect(result.key == "lastSync")
    #expect(result.date == syncDate)
    #expect(result.eventsProcessed == 150)
    #expect(result.rateLimitRemaining == 4850)
    #expect(result.rateLimitReset == resetDate)
  }

  @Test("Unique constraint upserts on duplicate key")
  func test_syncMetadata_uniqueConstraint_upsertsOnDuplicateKey() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    let secondDate = Date(timeIntervalSince1970: 1_700_100_000)
    let resetDate = Date(timeIntervalSince1970: 1_700_200_000)

    let first = SyncMetadata(
      key: "lastSync",
      date: firstDate,
      eventsProcessed: 50,
      rateLimitRemaining: 4950,
      rateLimitReset: resetDate
    )
    context.insert(first)
    try context.save()

    let second = SyncMetadata(
      key: "lastSync",
      date: secondDate,
      eventsProcessed: 200,
      rateLimitRemaining: 4700,
      rateLimitReset: resetDate
    )
    context.insert(second)
    try context.save()

    let descriptor = FetchDescriptor<SyncMetadata>()
    let fetched = try context.fetch(descriptor)

    #expect(fetched.count == 1)
    #expect(fetched[0].date == secondDate)
    #expect(fetched[0].eventsProcessed == 200)
    #expect(fetched[0].rateLimitRemaining == 4700)
  }
}

// MARK: - SchemaTests

@Suite("Schema versioning and migration plan")
struct SchemaTests {

  @Test("SchemaV1 version identifier is 1.0.0")
  func test_schemaV1_versionIdentifier_isCorrect() {
    #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
  }

  @Test("SchemaV1 models contains all six model types")
  func test_schemaV1_models_containsAllSixTypes() {
    let models = SchemaV1.models
    #expect(models.count == 6)

    let typeNames = models.map { String(describing: $0) }
    #expect(typeNames.contains("Contribution"))
    #expect(typeNames.contains("Repository"))
    #expect(typeNames.contains("LanguageStat"))
    #expect(typeNames.contains("PullRequest"))
    #expect(typeNames.contains("UserProfile"))
    #expect(typeNames.contains("SyncMetadata"))
  }

  @Test("Migration plan schemas contains SchemaV1")
  func test_migrationPlan_schemas_containsV1() {
    let schemas = GitPulseSchemaMigrationPlan.schemas
    #expect(schemas.count == 1)
  }

  @Test("Migration plan stages is empty for v1")
  func test_migrationPlan_stages_isEmpty() {
    #expect(GitPulseSchemaMigrationPlan.stages.isEmpty)
  }
}

// MARK: - ModelContainerTests

@Suite("In-memory ModelContainer")
@MainActor
struct ModelContainerTests {

  @Test("TestModelContainer creates successfully")
  func test_inMemoryModelContainer_createsSuccessfully() throws {
    let container = try TestModelContainer.create()
    #expect(container.mainContext != nil)
  }
}
