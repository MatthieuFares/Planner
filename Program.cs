using Microsoft.EntityFrameworkCore;
using PlannerAPI.Data;
using PlannerAPI.Services.Implementations;
using PlannerAPI.Services.Interfaces;
using Swashbuckle.AspNetCore.SwaggerGen;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
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
builder.Services.AddScoped<IProjectCalendarPeriodService,ProjectCalendarPeriodService>();
builder.Services.AddScoped<IPlanningVersionService,PlanningVersionService>();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();