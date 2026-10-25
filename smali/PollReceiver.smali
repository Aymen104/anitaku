.class public Lcom/anitaku/patch/PollReceiver;
.super Landroid/content/BroadcastReceiver;
.source "PollReceiver.java"


# direct methods
.method public constructor <init>()V
    .locals 0

    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V

    return-void
.end method


# virtual methods
.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .locals 2

    :try_start
    invoke-static {p1}, Lcom/anitaku/patch/EpisodePoller;->check(Landroid/content/Context;)V

    invoke-virtual {p2}, Landroid/content/Intent;->getAction()Ljava/lang/String;

    move-result-object v0

    const-string v1, "android.intent.action.BOOT_COMPLETED"

    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v1

    if-eqz v1, :cond_0

    invoke-static {p1}, Lcom/anitaku/patch/EpisodePoller;->schedule(Landroid/content/Context;)V

    :cond_0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all

    return-void

    :catch_all
    move-exception v0

    return-void
.end method
