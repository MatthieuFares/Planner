using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;
using PlannerAPI.Data;
using PlannerAPI.Models;
using PlannerAPI.Services.Implementations;
using PlannerAPI.Services.Interfaces;
using PlannerAPI.Services.ProjectInterop;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();

builder.Services.AddHttpContextAccessor();

builder.Services.AddScoped<ICurrentUserService, CurrentUserService>();
builder.Services.AddScoped<IProjectAuthorizationService, ProjectAuthorizationService>();
builder.Services.AddScoped<IProjectMemberService, ProjectMemberService>();
builder.Services.AddScoped<IProjectService, ProjectService>();
builder.Services.AddScoped<ITaskService, TaskService>();
builder.Services.AddScoped<ITaskDependencyService, TaskDependencyService>();
builder.Services.AddScoped<ITaskSchedulingService, TaskSchedulingService>();
builder.Services.AddScoped<IResourceService, ResourceService>();
builder.Services.AddScoped<IResourceAssignmentService, ResourceAssignmentService>();
builder.Services.AddScoped<IResourceAnalysisService, ResourceAnalysisService>();
builder.Services.AddScoped<IResourceGroupService, ResourceGroupService>();
builder.Services.AddScoped<IProjectSummaryService, ProjectSummaryService>();
builder.Services.AddScoped<IProjectWarningService, ProjectWarningService>();
builder.Services.AddScoped<IPlanningItemService, PlanningItemService>();
builder.Services.AddScoped<IProjectCalendarService, ProjectCalendarService>();
builder.Services.AddScoped<IProjectCalendarExceptionService, ProjectCalendarExceptionService>();
builder.Services.AddScoped<IProjectBaselineService, ProjectBaselineService>();
builder.Services.AddScoped<IProjectCalendarPeriodService, ProjectCalendarPeriodService>();
builder.Services.AddScoped<IPlanningVersionService, PlanningVersionService>();

builder.Services.AddScoped<MicrosoftProjectXmlParser>();
builder.Services.AddScoped<ProjectInteropImportService>();
builder.Services.AddScoped<MicrosoftProjectXmlWriter>();
builder.Services.AddScoped<ProjectInteropExportService>();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services
    .AddIdentityApiEndpoints<AppUser>(options =>
    {
        options.SignIn.RequireConfirmedEmail = false;
        options.SignIn.RequireConfirmedAccount = false;
        options.User.RequireUniqueEmail = true;

        options.Password.RequiredLength = 10;
        options.Password.RequireDigit = true;
        options.Password.RequireLowercase = true;
        options.Password.RequireUppercase = true;
        options.Password.RequireNonAlphanumeric = true;

        options.Lockout.AllowedForNewUsers = true;
        options.Lockout.MaxFailedAccessAttempts = 5;
        options.Lockout.DefaultLockoutTimeSpan =
            TimeSpan.FromMinutes(15);
    })
    .AddRoles<IdentityRole>()
    .AddEntityFrameworkStores<AppDbContext>();

builder.Services.AddAuthorization();

builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen(options =>
{
    options.AddSecurityDefinition(
        "Bearer",
        new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            Description =
                "Access token ASP.NET Core Identity. " +
                "Saisir uniquement le token, sans préfixe Bearer."
        });

    options.AddSecurityRequirement(
        document => new OpenApiSecurityRequirement
        {
            [new OpenApiSecuritySchemeReference(
                "Bearer",
                document)] = []
        });
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var roleManager =
        scope.ServiceProvider
            .GetRequiredService<RoleManager<IdentityRole>>();

    var globalRoles = new[]
    {
        "Admin",
        "User"
    };

    foreach (var roleName in globalRoles)
    {
        if (await roleManager.RoleExistsAsync(roleName))
            continue;

        var result =
            await roleManager.CreateAsync(
                new IdentityRole(roleName));

        if (!result.Succeeded)
        {
            var errors = string.Join(
                " | ",
                result.Errors.Select(
                    error =>
                        $"{error.Code}: {error.Description}"));

            throw new InvalidOperationException(
                $"Impossible de créer le rôle global " +
                $"« {roleName} » : {errors}");
        }
    }
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthentication();
app.UseAuthorization();

var authGroup = app.MapGroup("/api/auth");
authGroup.MapIdentityApi<AppUser>();

app.MapGet(
        "/api/auth/ping",
        () => Results.Ok(
            new
            {
                authenticated = true,
                message = "Authentification Planner valide."
            }))
    .RequireAuthorization();

app.MapControllers();

app.Run();