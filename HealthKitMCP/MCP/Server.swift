import MCP

actor HealthKitMCPServer {
    private let server: Server
    let transport: StatelessHTTPServerTransport
    private let healthKit: HealthKitManager
    private let workoutKit: WorkoutKitManager

    init() {
        // Disable origin validation: requests come from a Mac on the local network,
        // not localhost, so the default localhost-only check would reject them.
        // Use stateless transport: no session management, so reconnections always work.
        let pipeline = StandardValidationPipeline(validators: [
            OriginValidator.disabled,
            AcceptHeaderValidator(mode: .jsonOnly),
            ContentTypeValidator(),
            ProtocolVersionValidator(),
        ])
        self.transport = StatelessHTTPServerTransport(validationPipeline: pipeline)
        self.healthKit = HealthKitManager()
        self.workoutKit = WorkoutKitManager()
        self.server = Server(
            name: "HealthKitMCP",
            version: "1.0.0",
            capabilities: Server.Capabilities(tools: .init(listChanged: false))
        )
    }

    func requestHealthKitAuthorization() async throws {
        try await healthKit.requestAuthorization()
    }

    func run() async throws {
        await server.withMethodHandler(ListTools.self) { _ in
            ListTools.Result(tools: Self.allTools)
        }

        await server.withMethodHandler(CallTool.self) { [self] params in
            await self.handleToolCall(params)
        }

        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }

    // MARK: - Dispatch

    private func handleToolCall(_ params: CallTool.Parameters) async -> CallTool.Result {
        let args = params.arguments ?? [:]
        do {
            let text: String
            switch params.name {
            case ScheduleWorkoutTool.toolName:
                text = try await ScheduleWorkoutTool.handle(args: args, manager: workoutKit)
            case QueryWorkoutsTool.toolName:
                text = try await QueryWorkoutsTool.handle(args: args, manager: healthKit)
            case QueryActivitySummaryTool.toolName:
                text = try await QueryActivitySummaryTool.handle(args: args, manager: healthKit)
            case QueryRestingHeartRateTool.toolName:
                text = try await QueryRestingHeartRateTool.handle(args: args, manager: healthKit)
            case QueryVO2MaxTool.toolName:
                text = try await QueryVO2MaxTool.handle(args: args, manager: healthKit)
            case QueryHRVTool.toolName:
                text = try await QueryHRVTool.handle(args: args, manager: healthKit)
            case QueryBodyMassTool.toolName:
                text = try await QueryBodyMassTool.handle(args: args, manager: healthKit)
            case QuerySleepTool.toolName:
                text = try await QuerySleepTool.handle(args: args, manager: healthKit)
            case QueryScheduledWorkoutsTool.toolName:
                text = try await QueryScheduledWorkoutsTool.handle(args: args, manager: workoutKit)
            case DeleteScheduledWorkoutTool.toolName:
                text = try await DeleteScheduledWorkoutTool.handle(args: args, manager: workoutKit)
            default:
                return Self.result(text: "Unknown tool: \(params.name)", isError: true)
            }
            return Self.result(text: text)
        } catch {
            return Self.result(text: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Tool Definitions

    private static let allTools: [Tool] = [
        ScheduleWorkoutTool.definition,
        QueryWorkoutsTool.definition,
        QueryActivitySummaryTool.definition,
        QueryRestingHeartRateTool.definition,
        QueryVO2MaxTool.definition,
        QueryHRVTool.definition,
        QueryBodyMassTool.definition,
        QuerySleepTool.definition,
        QueryScheduledWorkoutsTool.definition,
        DeleteScheduledWorkoutTool.definition,
    ]

    private static func result(text: String, isError: Bool = false) -> CallTool.Result {
        CallTool.Result(
            content: [.text(text: text, annotations: nil, _meta: nil)],
            isError: isError
        )
    }
}
