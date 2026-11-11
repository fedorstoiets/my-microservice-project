from django.db import models


class PageVisit(models.Model):
    visited_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Visit #{self.pk}"
