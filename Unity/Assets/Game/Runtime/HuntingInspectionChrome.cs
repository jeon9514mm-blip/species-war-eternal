using System;
using System.Linq;
using UnityEngine;
using UnityEngine.UIElements;

namespace Eternal.UnityMigration
{
    public sealed partial class HuntingMigrationReview
    {
        enum InspectionLayout { Sheet, Wide, Drawer }
        VisualElement inspectionShade;
        VisualElement inspectionFocusReturn;
        InspectionLayout inspectionLayout;
        bool inspectionWasVisible;
        const string SkillEffectsPreference = "Eternal.UI.SkillEffects";
        const string SoundEffectsPreference = "Eternal.UI.SoundEffects";
        bool SkillEffectsEnabled => PlayerPrefs.GetInt(SkillEffectsPreference, 1) != 0;
        bool SoundEffectsEnabled => PlayerPrefs.GetInt(SoundEffectsPreference, 1) != 0;
        bool InspectionIsOpen => modal != null && modal.style.display.value != DisplayStyle.None;

        // One overlay owns input for every screen. Combat continues through its
        // existing clock, but pointer events cannot fall through to the arena.
        void PrepareInspectionChrome()
        {
            inspectionShade = new VisualElement { name = "inspection-backdrop" };
            inspectionShade.AddToClassList("inspection-backdrop");
            inspectionShade.style.position = Position.Absolute;
            inspectionShade.style.left = inspectionShade.style.right = 0;
            inspectionShade.style.top = inspectionShade.style.bottom = 0;
            inspectionShade.style.backgroundColor = new Color(.012f, .02f, .024f, .76f);
            inspectionShade.style.display = DisplayStyle.None;
            root.Add(inspectionShade);
            modal.RemoveFromHierarchy();
            inspectionShade.Add(modal);
            modal.AddToClassList("inspection-window");
            modal.focusable = true;
            modal.style.paddingBottom = 16;
            modal.style.overflow = Overflow.Hidden;
            inspectionShade.RegisterCallback<PointerDownEvent>(e =>
            {
                if (e.target == inspectionShade) CloseInspection();
                e.StopPropagation();
            });
            inspectionShade.RegisterCallback<PointerUpEvent>(e => e.StopPropagation());
            inspectionShade.RegisterCallback<WheelEvent>(e => e.StopPropagation());
            root.RegisterCallback<KeyDownEvent>(e =>
            {
                if (e.keyCode != KeyCode.Escape || !InspectionIsOpen) return;
                CloseInspection();
                e.StopPropagation();
            }, TrickleDown.TrickleDown);
            root.RegisterCallback<GeometryChangedEvent>(_ =>
            {
                if (InspectionIsOpen) ApplyInspectionBounds();
            });
            // Existing gameplay paths also close modal directly (raid entry,
            // profile changes). Keep the single blocker in sync with them.
            root.schedule.Execute(SyncInspectionVisibility).Every(50);
            feedback.SetSkillEffects(SkillEffectsEnabled);
            feedback.SetSoundEffects(SoundEffectsEnabled);
        }

        void ConfigureInspection(InspectionLayout layout)
        {
            inspectionLayout = layout;
            modal.EnableInClassList("inspection-wide", layout == InspectionLayout.Wide);
            modal.EnableInClassList("inspection-drawer", layout == InspectionLayout.Drawer);
            modal.EnableInClassList("inspection-sheet", layout == InspectionLayout.Sheet);
            ApplyInspectionBounds();
        }

        void ApplyInspectionBounds()
        {
            float width = root.resolvedStyle.width;
            float height = root.resolvedStyle.height;
            if (float.IsNaN(width) || width <= 0) width = 1600;
            if (float.IsNaN(height) || height <= 0) height = 900;
            float margin = width < 900 ? 10 : 18;
            modal.style.right = margin;
            modal.style.top = height < 600 ? margin : 86;
            modal.style.bottom = height < 600 ? margin : 106;
            modal.style.maxHeight = StyleKeyword.None;
            modal.style.minWidth = 0;
            modal.style.minHeight = 0;
            if (inspectionLayout == InspectionLayout.Wide)
            {
                modal.style.left = margin;
                modal.style.width = StyleKeyword.Auto;
            }
            else
            {
                modal.style.left = StyleKeyword.Auto;
                modal.style.width = Mathf.Min(width - margin * 2,
                    inspectionLayout == InspectionLayout.Drawer ? 900 : 580);
            }
        }

        void OpenInspection(string title)
        {
            bool opening = !InspectionIsOpen;
            if (opening) inspectionFocusReturn = root.focusController?.focusedElement as VisualElement;
            modal.Clear();
            modal.RemoveFromClassList("hero-showcase");
            modal.RemoveFromClassList("legacy-menu-drawer");
            modal.style.display = DisplayStyle.Flex;
            ConfigureInspection(InspectionLayout.Sheet);
            if (inspectionShade != null)
            {
                inspectionShade.style.display = DisplayStyle.Flex;
                inspectionShade.BringToFront();
                inspectionWasVisible = true;
            }
            var header = Row(modal);
            header.name = "inspection-header";
            header.AddToClassList("inspection-header");
            header.style.height = 48;
            header.style.flexShrink = 0;
            header.style.alignItems = Align.Center;
            header.style.marginBottom = 10;
            var heading = Text(header, title, 23);
            heading.name = "inspection-title";
            heading.style.flexGrow = 1;
            heading.style.minWidth = 0;
            heading.style.overflow = Overflow.Hidden;
            heading.style.textOverflow = TextOverflow.Ellipsis;
            var close = Button(header, "닫기", CloseInspection);
            close.name = "inspection-close";
            close.tooltip = "닫기 · Esc";
            close.style.minWidth = 64;
            close.style.height = 40;
            modal.Focus();
            if (chainStrip != null) RefreshChainStrip();
        }

        void SyncInspectionVisibility()
        {
            if (inspectionShade == null || modal == null) return;
            bool shown = InspectionIsOpen;
            inspectionShade.style.display = shown ? DisplayStyle.Flex : DisplayStyle.None;
            if (!shown && inspectionWasVisible)
            {
                heroShowcaseReturn = null;
                if (inspectionFocusReturn != null && inspectionFocusReturn.panel != null)
                    inspectionFocusReturn.Focus();
                inspectionFocusReturn = null;
                SelectNavigation(Raid == null ? "사냥" : "도전");
            }
            inspectionWasVisible = shown;
        }

        void CloseInspection()
        {
            heroShowcaseReturn = null;
            modal.style.display = DisplayStyle.None;
            SyncInspectionVisibility();
            if (chainStrip != null) RefreshChainStrip();
        }

        void OpenHeroManagement()
        {
            var id = ReviewState.DeployedHeroes().FirstOrDefault();
            if (string.IsNullOrEmpty(id)) id = Simulation.Catalog.HeroIds.FirstOrDefault(ReviewState.IsFactionHero);
            if (!string.IsNullOrEmpty(id)) ShowHeroShowcase(id);
            else ShowRoster();
        }

        void SetSkillEffectsEnabled(bool value)
        {
            PlayerPrefs.SetInt(SkillEffectsPreference, value ? 1 : 0);
            PlayerPrefs.Save();
            feedback.SetSkillEffects(value);
        }

        void SetSoundEffectsEnabled(bool value)
        {
            PlayerPrefs.SetInt(SoundEffectsPreference, value ? 1 : 0);
            PlayerPrefs.Save();
            feedback.SetSoundEffects(value);
        }
    }
}
